package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/hashicorp/nomad/api"
	"go.temporal.io/sdk/activity"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

// TrivyScanWorkflow orchestrates image vulnerability scanning
func TrivyScanWorkflow(ctx workflow.Context) error {
	ctx = workflow.WithActivityOptions(ctx, workflow.ActivityOptions{
		StartToCloseTimeout: 30 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    1 * time.Second,
			BackoffCoefficient: 2.0,
			MaxInterval:        1 * time.Minute,
			MaxAttempts:        3,
		},
	})

	var images []string
	// Activity 1: Get all running images from Nomad
	err := workflow.ExecuteActivity(ctx, GetRunningImages).Get(ctx, &images)
	if err != nil {
		return fmt.Errorf("failed to get running images: %w", err)
	}

	workflow.GetLogger(ctx).Info("Starting image scans", "image_count", len(images))

	// Activity 2: Scan each image (sequential for now)
	var scanResults []ScanResult
	for _, img := range images {
		var result ScanResult
		err := workflow.ExecuteActivity(ctx, ScanImage, img).Get(ctx, &result)
		if err != nil {
			// Log but continue
			workflow.GetLogger(ctx).Warn("scan activity error", "image", img, "error", err)
			result = ScanResult{
				Image:     img,
				Status:    "error",
				Error:     err.Error(),
				ScannedAt: time.Now(),
			}
		}
		scanResults = append(scanResults, result)
	}

	// Activity 3: Generate and store report
	var reportPath string
	err = workflow.ExecuteActivity(ctx, GenerateReport, scanResults).Get(ctx, &reportPath)
	if err != nil {
		return fmt.Errorf("failed to generate report: %w", err)
	}

	workflow.GetLogger(ctx).Info("Scan complete", "report_path", reportPath)

	// Check for critical vulns and fail if found
	for _, result := range scanResults {
		if result.CriticalCount > 0 || result.HighCount > 0 {
			return fmt.Errorf("critical or high vulnerabilities found: %s", reportPath)
		}
	}

	return nil
}

// ScanResult holds vulnerability scan results for one image
type ScanResult struct {
	Image         string    `json:"image"`
	Status        string    `json:"status"` // "success", "pull_failed", "error"
	Error         string    `json:"error,omitempty"`
	CriticalCount int       `json:"critical_count"`
	HighCount     int       `json:"high_count"`
	MediumCount   int       `json:"medium_count"`
	LowCount      int       `json:"low_count"`
	ScannedAt     time.Time `json:"scanned_at"`
}

// GetRunningImages queries Nomad for all running Docker images
func GetRunningImages(ctx context.Context) ([]string, error) {
	nomadAddr := os.Getenv("NOMAD_ADDR")
	if nomadAddr == "" {
		nomadAddr = "http://127.0.0.1:4646"
	}

	config := api.DefaultConfig()
	config.Address = nomadAddr
	config.TLSConfig.Insecure = true

	nomadClient, err := api.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Nomad client: %w", err)
	}

	allocs, _, err := nomadClient.Allocations().List(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list allocations: %w", err)
	}

	imageMap := make(map[string]bool)
	for _, alloc := range allocs {
		if alloc.ClientStatus != "running" {
			continue
		}

		allocDetail, _, err := nomadClient.Allocations().Info(alloc.ID, nil)
		if err != nil {
			continue
		}

		for _, task := range allocDetail.AllocatedResources.Tasks {
			if task.Config != nil {
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

	activity.GetLogger(ctx).Info("Found running images", "count", len(images))
	return images, nil
}

// ScanImage runs trivy on a single image
func ScanImage(ctx context.Context, image string) (ScanResult, error) {
	result := ScanResult{
		Image:     image,
		Status:    "success",
		ScannedAt: time.Now(),
	}

	activity.GetLogger(ctx).Info("Scanning image", "image", image)

	// Run trivy scan
	cmd := exec.CommandContext(ctx, "trivy", "image", "--format", "json", image)
	var out bytes.Buffer
	var errOut bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errOut

	err := cmd.Run()
	if err != nil {
		errMsg := errOut.String()
		if strings.Contains(errMsg, "connection refused") || strings.Contains(errMsg, "pull") {
			result.Status = "pull_failed"
			result.Error = errMsg
			activity.GetLogger(ctx).Warn("Failed to pull image", "image", image, "error", errMsg)
			return result, nil
		}
		result.Status = "error"
		result.Error = fmt.Sprintf("%v: %s", err, errMsg)
		activity.GetLogger(ctx).Error("Scan failed", "image", image, "error", result.Error)
		return result, nil
	}

	// Parse trivy JSON output
	var trivyResult struct {
		Results []struct {
			Vulnerabilities []struct {
				Severity string `json:"Severity"`
			} `json:"Vulnerabilities"`
		} `json:"Results"`
	}

	if err := json.Unmarshal(out.Bytes(), &trivyResult); err != nil {
		result.Status = "error"
		result.Error = fmt.Sprintf("failed to parse trivy output: %v", err)
		return result, nil
	}

	// Count severities
	for _, res := range trivyResult.Results {
		for _, vuln := range res.Vulnerabilities {
			switch vuln.Severity {
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

	activity.GetLogger(ctx).Info("Scan complete", "image", image, "critical", result.CriticalCount, "high", result.HighCount)
	return result, nil
}

// GenerateReport creates a summary report and writes to /mnt/gdrive
func GenerateReport(ctx context.Context, results []ScanResult) (string, error) {
	timestamp := time.Now().Format("2006-01-02-15-04-05")
	reportDir := "/mnt/gdrive/trivy-reports"
	reportFile := filepath.Join(reportDir, fmt.Sprintf("scan-report-%s.json", timestamp))

	if err := os.MkdirAll(reportDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create report directory: %w", err)
	}

	// Calculate summary
	summary := struct {
		ScanTime      time.Time    `json:"scan_time"`
		TotalImages   int          `json:"total_images"`
		Successful    int          `json:"successful"`
		PullFailed    int          `json:"pull_failed"`
		Errors        int          `json:"errors"`
		CriticalTotal int          `json:"critical_total"`
		HighTotal     int          `json:"high_total"`
		Results       []ScanResult `json:"results"`
	}{
		ScanTime:    time.Now(),
		TotalImages: len(results),
		Results:     results,
	}

	for _, r := range results {
		if r.Status == "success" {
			summary.Successful++
		} else if r.Status == "pull_failed" {
			summary.PullFailed++
		} else if r.Status == "error" {
			summary.Errors++
		}
		summary.CriticalTotal += r.CriticalCount
		summary.HighTotal += r.HighCount
	}

	data, err := json.MarshalIndent(summary, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal report: %w", err)
	}

	if err := os.WriteFile(reportFile, data, 0644); err != nil {
		return "", fmt.Errorf("failed to write report: %w", err)
	}

	activity.GetLogger(ctx).Info("Report generated", "path", reportFile, "critical", summary.CriticalTotal, "high", summary.HighTotal)
	return reportFile, nil
}

// Register activities and start worker
func main() {
	c, err := client.Dial(client.Options{
		HostPort: os.Getenv("TEMPORAL_ADDRESS"),
	})
	if err != nil {
		log.Fatalf("Failed to create Temporal client: %v", err)
	}
	defer c.Close()

	w := worker.New(c, "backup-task-queue", worker.Options{})

	w.RegisterWorkflow(TrivyScanWorkflow)
	w.RegisterActivity(GetRunningImages)
	w.RegisterActivity(ScanImage)
	w.RegisterActivity(GenerateReport)

	if err := w.Run(worker.InterruptCh()); err != nil {
		log.Fatalf("Worker error: %v", err)
	}
}
