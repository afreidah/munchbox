// ============================================================================
// Trivy Vulnerability Scanner Workflow
// ============================================================================
//
// Package: main
// Purpose: Scans all running container images in the Nomad cluster for vulnerabilities
//
// This workflow discovers all Docker images running in Nomad allocations,
// scans each with Trivy, and stores detailed CVE results in PostgreSQL.
//
// Activities:
//   - DownloadTrivyDB: Downloads the vulnerability database once before scanning
//   - GetRunningImages: Queries Nomad API for all running Docker images
//   - ScanImage: Runs Trivy against a single image
//   - SaveToPostgres: Stores scan results and vulnerabilities in PostgreSQL
//
// Author: Alex Freidah
// Repository: munchbox/temporal-backup-worker
// ============================================================================
package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/XSAM/otelsql"
	"github.com/hashicorp/nomad/api"
	_ "github.com/lib/pq"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"
	"go.temporal.io/sdk/activity"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

// tracer is used for creating spans in activities
var tracer = otel.Tracer("temporal-backup-worker")

// Vulnerability holds details about a single CVE
type Vulnerability struct {
	VulnID           string `json:"vuln_id"`
	Severity         string `json:"severity"`
	PkgName          string `json:"pkg_name"`
	InstalledVersion string `json:"installed_version"`
	FixedVersion     string `json:"fixed_version"`
	Title            string `json:"title"`
	Description      string `json:"description"`
}

// TrivyScanResult holds vulnerability scan results for one image
type TrivyScanResult struct {
	Image           string          `json:"image"`
	Status          string          `json:"status"` // "success", "pull_failed", "error"
	Error           string          `json:"error,omitempty"`
	CriticalCount   int             `json:"critical_count"`
	HighCount       int             `json:"high_count"`
	MediumCount     int             `json:"medium_count"`
	LowCount        int             `json:"low_count"`
	Vulnerabilities []Vulnerability `json:"vulnerabilities"`
	ScannedAt       time.Time       `json:"scanned_at"`
}

// TrivyScanWorkflow orchestrates image vulnerability scanning across the cluster.
// Scans are executed in parallel batches using Trivy server mode for concurrency.
func TrivyScanWorkflow(ctx workflow.Context) error {
	logger := workflow.GetLogger(ctx)
	logger.Info("Starting Trivy vulnerability scan workflow")

	const batchSize = 10 // Concurrent scans via Trivy server (handles DB locking internally)

	activityOpts := workflow.ActivityOptions{
		StartToCloseTimeout: 30 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    time.Minute,
			MaximumAttempts:    3,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, activityOpts)

	// Activity 1: Get all running images from Nomad
	var images []string
	err := workflow.ExecuteActivity(ctx, GetRunningImages).Get(ctx, &images)
	if err != nil {
		return fmt.Errorf("failed to get running images: %w", err)
	}
	logger.Info("Found images to scan", "count", len(images))

	// Activity 2: Scan images in batches to avoid OOM
	var totalCritical, totalHigh int
	var totalScans int

	for i := 0; i < len(images); i += batchSize {
		end := i + batchSize
		if end > len(images) {
			end = len(images)
		}
		batch := images[i:end]
		logger.Info("Processing batch", "batch", i/batchSize+1, "images", len(batch))

		// Launch scans for this batch
		type scanFuture struct {
			image  string
			future workflow.Future
		}
		futures := make([]scanFuture, len(batch))
		for j, img := range batch {
			scanCtx := workflow.WithActivityOptions(ctx, workflow.ActivityOptions{
				ActivityID:          fmt.Sprintf("ScanImage:%s", img),
				StartToCloseTimeout: 30 * time.Minute,
				RetryPolicy: &temporal.RetryPolicy{
					InitialInterval:    time.Second,
					BackoffCoefficient: 2.0,
					MaximumInterval:    time.Minute,
					MaximumAttempts:    3,
				},
			})
			futures[j] = scanFuture{
				image:  img,
				future: workflow.ExecuteActivity(scanCtx, ScanImage, img),
			}
		}

		// Wait for batch to complete and save results
		for _, sf := range futures {
			var result TrivyScanResult
			err := sf.future.Get(ctx, &result)
			if err != nil {
				logger.Warn("Scan activity error", "image", sf.image, "error", err)
				result = TrivyScanResult{
					Image:     sf.image,
					Status:    "error",
					Error:     err.Error(),
					ScannedAt: workflow.Now(ctx),
				}
			}

			// Save each scan result individually to PostgreSQL
			saveCtx := workflow.WithActivityOptions(ctx, workflow.ActivityOptions{
				ActivityID:          fmt.Sprintf("SaveScan:%s", sf.image),
				StartToCloseTimeout: 5 * time.Minute,
				RetryPolicy: &temporal.RetryPolicy{
					InitialInterval:    time.Second,
					BackoffCoefficient: 2.0,
					MaximumInterval:    time.Minute,
					MaximumAttempts:    3,
				},
			})
			err = workflow.ExecuteActivity(saveCtx, SaveScanToPostgres, result).Get(ctx, nil)
			if err != nil {
				logger.Error("Failed to save scan result", "image", sf.image, "error", err)
			}

			totalCritical += result.CriticalCount
			totalHigh += result.HighCount
			totalScans++
		}
	}

	logger.Info("Trivy scan complete",
		"images", totalScans,
		"critical", totalCritical,
		"high", totalHigh)

	if totalCritical > 0 || totalHigh > 0 {
		logger.Warn("Vulnerabilities found", "critical", totalCritical, "high", totalHigh)
	}

	return nil
}


// GetRunningImages queries Nomad for all unique Docker images in running allocations.
func GetRunningImages(ctx context.Context) ([]string, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Discovering running images from Nomad")

	nomadAddr := os.Getenv("NOMAD_ADDR")
	if nomadAddr == "" {
		nomadAddr = "https://nomad.service.consul:4646"
	}
	config := api.DefaultConfig()
	config.Address = nomadAddr

	if token := os.Getenv("NOMAD_TOKEN"); token != "" {
		config.SecretID = token
	}
	if caCert := os.Getenv("NOMAD_CACERT"); caCert != "" {
		config.TLSConfig.CACert = caCert
	}

	// Wrap HTTP transport with OpenTelemetry instrumentation for service graph visibility
	config.HttpClient = &http.Client{
		Transport: otelhttp.NewTransport(
			http.DefaultTransport,
			otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
				return fmt.Sprintf("nomad.%s", r.URL.Path)
			}),
		),
	}

	client, err := api.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Nomad client: %w", err)
	}

	allocs, _, err := client.Allocations().List(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list allocations: %w", err)
	}

	imageMap := make(map[string]bool)
	for _, allocStub := range allocs {
		if allocStub.ClientStatus != "running" {
			continue
		}

		alloc, _, err := client.Allocations().Info(allocStub.ID, nil)
		if err != nil {
			logger.Warn("Failed to get allocation info", "alloc_id", allocStub.ID, "error", err)
			continue
		}

		if alloc.Job == nil {
			continue
		}

		for _, tg := range alloc.Job.TaskGroups {
			for _, task := range tg.Tasks {
				if task.Driver != "docker" || task.Config == nil {
					continue
				}
				if img, ok := task.Config["image"]; ok {
					if imgStr, ok := img.(string); ok && imgStr != "" {
						imageMap[imgStr] = true
					}
				}
			}
		}
	}

	var images []string
	for img := range imageMap {
		images = append(images, img)
	}

	logger.Info("Found unique images", "count", len(images))
	return images, nil
}

// ScanImage runs Trivy vulnerability scanner against a single container image.
// Uses Trivy server mode for concurrent scanning without DB lock contention.
func ScanImage(ctx context.Context, image string) (TrivyScanResult, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Scanning image", "image", image)

	result := TrivyScanResult{
		Image:     image,
		Status:    "success",
		ScannedAt: time.Now(),
	}

	// Get Trivy server address from environment or use Consul service discovery
	trivyServer := os.Getenv("TRIVY_SERVER_ADDR")
	if trivyServer == "" {
		trivyServer = "http://trivy-server.service.consul:4954"
	}

	// Create span for trivy CLI execution (shows as client call to trivy-server)
	ctx, span := tracer.Start(ctx, "trivy.scan",
		trace.WithSpanKind(trace.SpanKindClient),
		trace.WithAttributes(
			attribute.String("trivy.image", image),
			attribute.String("trivy.server", trivyServer),
			semconv.PeerService("trivy-server"),
		),
	)
	defer span.End()

	// Run trivy in client mode, connecting to the server
	cmd := exec.CommandContext(ctx, "trivy", "image",
		"--server", trivyServer,
		"--format", "json",
		"--timeout", "10m",
		"--scanners", "vuln",
		image)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		errMsg := stderr.String()
		if strings.Contains(errMsg, "pull") ||
			strings.Contains(errMsg, "manifest unknown") ||
			strings.Contains(errMsg, "connection refused") {
			result.Status = "pull_failed"
			result.Error = errMsg
			span.SetStatus(codes.Error, "pull_failed")
			span.SetAttributes(attribute.String("trivy.error", errMsg))
			logger.Warn("Failed to pull image", "image", image, "error", errMsg)
			return result, nil
		}
		result.Status = "error"
		result.Error = fmt.Sprintf("%v: %s", err, errMsg)
		span.SetStatus(codes.Error, "scan_failed")
		span.SetAttributes(attribute.String("trivy.error", result.Error))
		logger.Error("Scan failed", "image", image, "error", result.Error)
		return result, nil
	}

	// Parse full trivy JSON output
	var trivyOutput struct {
		Results []struct {
			Vulnerabilities []struct {
				VulnerabilityID  string `json:"VulnerabilityID"`
				Severity         string `json:"Severity"`
				PkgName          string `json:"PkgName"`
				InstalledVersion string `json:"InstalledVersion"`
				FixedVersion     string `json:"FixedVersion"`
				Title            string `json:"Title"`
				Description      string `json:"Description"`
			} `json:"Vulnerabilities"`
		} `json:"Results"`
	}

	if err := json.Unmarshal(stdout.Bytes(), &trivyOutput); err != nil {
		result.Status = "error"
		result.Error = fmt.Sprintf("failed to parse trivy output: %v", err)
		return result, nil
	}

	// Collect vulnerabilities and count by severity
	seen := make(map[string]bool) // dedupe by VulnID
	for _, res := range trivyOutput.Results {
		for _, vuln := range res.Vulnerabilities {
			if seen[vuln.VulnerabilityID] {
				continue
			}
			seen[vuln.VulnerabilityID] = true

			result.Vulnerabilities = append(result.Vulnerabilities, Vulnerability{
				VulnID:           vuln.VulnerabilityID,
				Severity:         vuln.Severity,
				PkgName:          vuln.PkgName,
				InstalledVersion: vuln.InstalledVersion,
				FixedVersion:     vuln.FixedVersion,
				Title:            vuln.Title,
				Description:      truncate(vuln.Description, 1000),
			})

			switch strings.ToUpper(vuln.Severity) {
			case "CRITICAL":
				result.CriticalCount++
			case "HIGH":
				result.HighCount++
			case "MEDIUM":
				result.MediumCount++
			case "LOW":
				result.LowCount++
			}
		}
	}

	// Record scan results on span
	span.SetAttributes(
		attribute.Int("trivy.critical", result.CriticalCount),
		attribute.Int("trivy.high", result.HighCount),
		attribute.Int("trivy.medium", result.MediumCount),
		attribute.Int("trivy.low", result.LowCount),
		attribute.Int("trivy.total", len(result.Vulnerabilities)),
	)

	logger.Info("Scan complete",
		"image", image,
		"critical", result.CriticalCount,
		"high", result.HighCount,
		"medium", result.MediumCount,
		"low", result.LowCount,
		"total_vulns", len(result.Vulnerabilities))

	return result, nil
}

// SaveScanToPostgres stores a single scan result and its vulnerabilities in PostgreSQL.
func SaveScanToPostgres(ctx context.Context, result TrivyScanResult) error {
	logger := activity.GetLogger(ctx)
	logger.Info("Saving scan result to PostgreSQL", "image", result.Image, "vulns", len(result.Vulnerabilities))

	// Get database connection string from environment
	dbHost := os.Getenv("TRIVY_DB_HOST")
	if dbHost == "" {
		dbHost = "postgres-shared.service.consul"
	}
	dbPort := os.Getenv("TRIVY_DB_PORT")
	if dbPort == "" {
		dbPort = "5432"
	}
	dbUser := os.Getenv("TRIVY_DB_USER")
	dbPass := os.Getenv("TRIVY_DB_PASSWORD")
	dbName := os.Getenv("TRIVY_DB_NAME")
	if dbName == "" {
		dbName = "trivy"
	}

	sslMode := os.Getenv("DB_SSLMODE")
	if sslMode == "" {
		sslMode = "verify-ca"
	}
	sslRootCert := os.Getenv("DB_SSLROOTCERT")
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPass, dbName, sslMode)
	if sslRootCert != "" {
		connStr += " sslrootcert=" + sslRootCert
	}

	// Use otelsql for automatic tracing of database operations (shows in service graph)
	db, err := otelsql.Open("postgres", connStr,
		otelsql.WithAttributes(
			semconv.DBSystemPostgreSQL,
			semconv.DBNamespace(dbName),
			semconv.ServerAddress(dbHost),
			semconv.ServerPort(5432),
		),
	)
	if err != nil {
		return fmt.Errorf("failed to connect to postgres: %w", err)
	}
	defer func() { _ = db.Close() }()

	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("failed to ping postgres: %w", err)
	}

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	// Insert scan record
	var scanID int
	err = tx.QueryRowContext(ctx,
		`INSERT INTO scans (image, status, error, scanned_at) VALUES ($1, $2, $3, $4) RETURNING id`,
		result.Image, result.Status, nullString(result.Error), result.ScannedAt,
	).Scan(&scanID)
	if err != nil {
		return fmt.Errorf("failed to insert scan for %s: %w", result.Image, err)
	}

	// Insert vulnerabilities
	for _, vuln := range result.Vulnerabilities {
		_, err := tx.ExecContext(ctx,
			`INSERT INTO vulnerabilities (scan_id, vuln_id, severity, pkg_name, installed_version, fixed_version, title, description)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
			scanID, vuln.VulnID, vuln.Severity, vuln.PkgName,
			vuln.InstalledVersion, nullString(vuln.FixedVersion),
			nullString(vuln.Title), nullString(vuln.Description),
		)
		if err != nil {
			return fmt.Errorf("failed to insert vulnerability %s: %w", vuln.VulnID, err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	logger.Info("Saved scan result to PostgreSQL", "image", result.Image)
	return nil
}

func nullString(s string) sql.NullString {
	if s == "" {
		return sql.NullString{}
	}
	return sql.NullString{String: s, Valid: true}
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}
