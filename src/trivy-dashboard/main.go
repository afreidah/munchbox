package main

import (
	"context"
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/XSAM/otelsql"
	_ "github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
	"go.temporal.io/api/workflowservice/v1"
	"go.temporal.io/sdk/client"
)

//go:embed templates/*
var templateFS embed.FS

//go:embed static/*
var staticFS embed.FS

var tracer trace.Tracer
var db *sql.DB
var temporalClient client.Client

// Prometheus metrics
var (
	requestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "trivy_dashboard_requests_total",
			Help: "Total HTTP requests",
		},
		[]string{"path", "method", "status"},
	)
	requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "trivy_dashboard_request_duration_seconds",
			Help:    "HTTP request duration",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path"},
	)
	imagesTotal = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "trivy_images_total",
			Help: "Total images in latest scan",
		},
	)
	vulnerabilities = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "trivy_vulnerabilities",
			Help: "Vulnerability counts by severity",
		},
		[]string{"severity"},
	)
)

type Scan struct {
	ID        int
	Image     string
	Status    string
	Error     sql.NullString
	ScannedAt time.Time
	Critical  int
	High      int
	Medium    int
	Low       int
}

type Vulnerability struct {
	VulnID           string
	Severity         string
	PkgName          string
	InstalledVersion string
	FixedVersion     sql.NullString
	Title            sql.NullString
	Description      sql.NullString
}

type ScanBatch struct {
	ID        string    `json:"id"`
	ScannedAt time.Time `json:"scanned_at"`
	Label     string    `json:"label"`
	Count     int       `json:"count"`
}

type DashboardData struct {
	Scans          []Scan
	ScanBatches    []ScanBatch
	SelectedBatch  string
	TotalImages    int
	CriticalTotal  int
	HighTotal      int
	MediumTotal    int
	LowTotal       int
	LastScanTime   time.Time
	Error          string
}

type DetailData struct {
	Scan            Scan
	Vulnerabilities []Vulnerability
	Error           string
}

func init() {
	prometheus.MustRegister(requestsTotal, requestDuration, imagesTotal, vulnerabilities)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Initialize database connection
	if err := initDB(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Initialize Temporal client
	if err := initTemporal(); err != nil {
		log.Printf("Warning: Failed to connect to Temporal: %v (scan trigger disabled)", err)
	} else {
		defer temporalClient.Close()
	}

	// Initialize OpenTelemetry
	shutdown := initTracer()
	defer shutdown()

	tracer = otel.Tracer("trivy-dashboard")
	tmpl := template.Must(template.ParseFS(templateFS, "templates/*.html"))

	mux := http.NewServeMux()

	// Serve static files (favicon, etc.)
	mux.Handle("/static/", http.FileServer(http.FS(staticFS)))

	// Dashboard - shows latest scan for each image
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ctx := r.Context()

		ctx, span := tracer.Start(ctx, "render-dashboard")
		defer span.End()

		// Get selected batch from query param (empty = latest)
		selectedBatch := r.URL.Query().Get("batch")

		data, err := loadDashboard(ctx, selectedBatch)
		if err != nil {
			data = DashboardData{Error: err.Error()}
			span.SetAttributes(attribute.String("error", err.Error()))
		} else {
			updateMetrics(data)
			span.SetAttributes(
				attribute.Int("images.total", data.TotalImages),
				attribute.Int("vulns.critical", data.CriticalTotal),
			)
		}

		w.Header().Set("Content-Type", "text/html")
		if err := tmpl.ExecuteTemplate(w, "index.html", data); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			requestsTotal.WithLabelValues("/", r.Method, "500").Inc()
			return
		}

		requestsTotal.WithLabelValues("/", r.Method, "200").Inc()
		requestDuration.WithLabelValues("/").Observe(time.Since(start).Seconds())
	})

	// Detail view - shows vulnerabilities for a specific scan
	mux.HandleFunc("/scan/", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ctx := r.Context()

		scanID := r.URL.Path[len("/scan/"):]
		ctx, span := tracer.Start(ctx, "render-detail")
		defer span.End()

		data, err := loadScanDetail(ctx, scanID)
		if err != nil {
			data = DetailData{Error: err.Error()}
		}

		w.Header().Set("Content-Type", "text/html")
		if err := tmpl.ExecuteTemplate(w, "detail.html", data); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			requestsTotal.WithLabelValues("/scan/", r.Method, "500").Inc()
			return
		}

		requestsTotal.WithLabelValues("/scan/", r.Method, "200").Inc()
		requestDuration.WithLabelValues("/scan/").Observe(time.Since(start).Seconds())
	})

	// Scan status - check if a scan is currently running
	mux.HandleFunc("/scan-status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		if temporalClient == nil {
			json.NewEncoder(w).Encode(map[string]interface{}{
				"running":   false,
				"available": false,
			})
			return
		}

		ctx := r.Context()
		// List workflows using visibility query via the workflow service
		resp, err := temporalClient.WorkflowService().ListWorkflowExecutions(ctx, &workflowservice.ListWorkflowExecutionsRequest{
			Namespace: "default",
			Query:     "WorkflowType = 'TrivyScanWorkflow' AND ExecutionStatus = 'Running'",
		})
		if err != nil {
			json.NewEncoder(w).Encode(map[string]interface{}{
				"running":   false,
				"available": true,
				"error":     err.Error(),
			})
			return
		}

		var runningWorkflow string
		if len(resp.Executions) > 0 && resp.Executions[0].GetExecution() != nil {
			runningWorkflow = resp.Executions[0].GetExecution().GetWorkflowId()
		}

		json.NewEncoder(w).Encode(map[string]interface{}{
			"running":     runningWorkflow != "",
			"available":   true,
			"workflow_id": runningWorkflow,
		})
	})

	// Trigger scan - starts a new Trivy scan workflow
	mux.HandleFunc("/trigger", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		ctx := r.Context()
		_, span := tracer.Start(ctx, "trigger-scan")
		defer span.End()

		if temporalClient == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Temporal client not available",
			})
			return
		}

		workflowID := fmt.Sprintf("trivy-scan-%s", time.Now().Format("20060102-150405"))
		run, err := temporalClient.ExecuteWorkflow(ctx, client.StartWorkflowOptions{
			ID:        workflowID,
			TaskQueue: "backup-task-queue",
		}, "TrivyScanWorkflow")

		if err != nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{
				"error": err.Error(),
			})
			requestsTotal.WithLabelValues("/trigger", r.Method, "500").Inc()
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]string{
			"status":      "started",
			"workflow_id": run.GetID(),
			"run_id":      run.GetRunID(),
		})
		requestsTotal.WithLabelValues("/trigger", r.Method, "202").Inc()
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		if err := db.Ping(); err != nil {
			http.Error(w, "db unhealthy", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	mux.Handle("/metrics", promhttp.Handler())

	handler := otelhttp.NewHandler(mux, "trivy-dashboard")

	log.Printf("Starting trivy-dashboard on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}

func initDB() error {
	dbHost := os.Getenv("TRIVY_DB_HOST")
	if dbHost == "" {
		dbHost = "postgres-replica.service.consul"
	}
	dbPort := os.Getenv("TRIVY_DB_PORT")
	if dbPort == "" {
		dbPort = "5433"
	}
	dbUser := os.Getenv("TRIVY_DB_USER")
	dbPass := os.Getenv("TRIVY_DB_PASSWORD")
	dbName := os.Getenv("TRIVY_DB_NAME")
	if dbName == "" {
		dbName = "trivy"
	}

	connStr := os.Getenv("DATABASE_URL")
	if connStr == "" {
		sslMode := os.Getenv("DB_SSLMODE")
		if sslMode == "" {
			sslMode = "verify-ca"
		}
		sslRootCert := os.Getenv("DB_SSLROOTCERT")
		connStr = "host=" + dbHost + " port=" + dbPort + " user=" + dbUser + " password=" + dbPass + " dbname=" + dbName + " sslmode=" + sslMode
		if sslRootCert != "" {
			connStr += " sslrootcert=" + sslRootCert
		}
	}

	var err error
	db, err = otelsql.Open("postgres", connStr,
		otelsql.WithAttributes(
			semconv.DBSystemPostgreSQL,
			attribute.String("db.name", dbName),
		),
	)
	if err != nil {
		return err
	}

	// Register stats to allow otel to report DB connection metrics
	if err := otelsql.RegisterDBStatsMetrics(db, otelsql.WithAttributes(
		semconv.DBSystemPostgreSQL,
	)); err != nil {
		log.Printf("Warning: Failed to register DB stats metrics: %v", err)
	}

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)

	return db.Ping()
}

func initTemporal() error {
	temporalAddr := os.Getenv("TEMPORAL_ADDRESS")
	if temporalAddr == "" {
		temporalAddr = "temporal-server.service.consul:7233"
	}

	// Retry connection with exponential backoff (container DNS may not be ready immediately)
	var err error
	maxRetries := 5
	for i := 0; i < maxRetries; i++ {
		temporalClient, err = client.Dial(client.Options{
			HostPort: temporalAddr,
		})
		if err == nil {
			log.Printf("Connected to Temporal at %s (attempt %d)", temporalAddr, i+1)
			return nil
		}
		if i < maxRetries-1 {
			delay := time.Duration(1<<uint(i)) * time.Second // 1s, 2s, 4s, 8s
			log.Printf("Failed to connect to Temporal (attempt %d/%d): %v, retrying in %v", i+1, maxRetries, err, delay)
			time.Sleep(delay)
		}
	}
	return err
}

func initTracer() func() {
	ctx := context.Background()

	otlpEndpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if otlpEndpoint == "" {
		otlpEndpoint = "tempo.service.consul:4317"
	}

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(otlpEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		log.Printf("Failed to create OTLP exporter: %v", err)
		return func() {}
	}

	res, _ := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("trivy-dashboard"),
			semconv.ServiceVersion("1.0.0"),
		),
	)

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		tp.Shutdown(ctx)
	}
}

func loadDashboard(ctx context.Context, selectedBatch string) (DashboardData, error) {
	_, span := tracer.Start(ctx, "load-dashboard")
	defer span.End()

	data := DashboardData{SelectedBatch: selectedBatch}

	// Get available scan batches (grouped by scan runs within 30 min windows)
	// Count unique images per batch (same image may be scanned multiple times if used in multiple jobs)
	batchRows, err := db.QueryContext(ctx, `
		SELECT
			to_char(date_trunc('hour', scanned_at) +
				INTERVAL '30 min' * FLOOR(EXTRACT(MINUTE FROM scanned_at) / 30), 'YYYY-MM-DD"T"HH24:MI') as batch_id,
			MIN(scanned_at) as batch_time,
			COUNT(DISTINCT image) as scan_count
		FROM scans
		GROUP BY batch_id
		ORDER BY batch_time DESC
		LIMIT 20
	`)
	if err != nil {
		return data, err
	}
	defer batchRows.Close()

	for batchRows.Next() {
		var batch ScanBatch
		if err := batchRows.Scan(&batch.ID, &batch.ScannedAt, &batch.Count); err != nil {
			return data, err
		}
		batch.Label = batch.ScannedAt.Format("Jan 02, 2006 15:04")
		data.ScanBatches = append(data.ScanBatches, batch)
	}

	// Default to latest batch if none selected
	if selectedBatch == "" && len(data.ScanBatches) > 0 {
		selectedBatch = data.ScanBatches[0].ID
		data.SelectedBatch = selectedBatch
	}

	// Get scans for selected batch with vulnerability counts
	// Deduplicate by image (same image may appear multiple times if used in different Nomad jobs)
	rows, err := db.QueryContext(ctx, `
		WITH batch_scans AS (
			SELECT DISTINCT ON (image) id, image, status, error, scanned_at
			FROM scans
			WHERE to_char(date_trunc('hour', scanned_at) +
				INTERVAL '30 min' * FLOOR(EXTRACT(MINUTE FROM scanned_at) / 30), 'YYYY-MM-DD"T"HH24:MI') = $1
			ORDER BY image, scanned_at DESC
		)
		SELECT
			s.id, s.image, s.status, s.error, s.scanned_at,
			COALESCE(SUM(CASE WHEN v.severity = 'CRITICAL' THEN 1 ELSE 0 END), 0) as critical,
			COALESCE(SUM(CASE WHEN v.severity = 'HIGH' THEN 1 ELSE 0 END), 0) as high,
			COALESCE(SUM(CASE WHEN v.severity = 'MEDIUM' THEN 1 ELSE 0 END), 0) as medium,
			COALESCE(SUM(CASE WHEN v.severity = 'LOW' THEN 1 ELSE 0 END), 0) as low
		FROM batch_scans s
		LEFT JOIN vulnerabilities v ON s.id = v.scan_id
		GROUP BY s.id, s.image, s.status, s.error, s.scanned_at
		ORDER BY critical DESC, high DESC, s.image
	`, selectedBatch)
	if err != nil {
		return data, err
	}
	defer rows.Close()

	for rows.Next() {
		var scan Scan
		err := rows.Scan(&scan.ID, &scan.Image, &scan.Status, &scan.Error, &scan.ScannedAt,
			&scan.Critical, &scan.High, &scan.Medium, &scan.Low)
		if err != nil {
			return data, err
		}
		data.Scans = append(data.Scans, scan)
		data.TotalImages++
		data.CriticalTotal += scan.Critical
		data.HighTotal += scan.High
		data.MediumTotal += scan.Medium
		data.LowTotal += scan.Low
		if scan.ScannedAt.After(data.LastScanTime) {
			data.LastScanTime = scan.ScannedAt
		}
	}

	return data, rows.Err()
}

func loadScanDetail(ctx context.Context, scanID string) (DetailData, error) {
	_, span := tracer.Start(ctx, "load-scan-detail")
	defer span.End()

	data := DetailData{}

	// Get scan info
	err := db.QueryRowContext(ctx, `
		SELECT id, image, status, error, scanned_at
		FROM scans WHERE id = $1
	`, scanID).Scan(&data.Scan.ID, &data.Scan.Image, &data.Scan.Status, &data.Scan.Error, &data.Scan.ScannedAt)
	if err != nil {
		return data, err
	}

	// Get vulnerabilities
	rows, err := db.QueryContext(ctx, `
		SELECT vuln_id, severity, pkg_name, installed_version, fixed_version, title, description
		FROM vulnerabilities
		WHERE scan_id = $1
		ORDER BY
			CASE severity
				WHEN 'CRITICAL' THEN 1
				WHEN 'HIGH' THEN 2
				WHEN 'MEDIUM' THEN 3
				WHEN 'LOW' THEN 4
				ELSE 5
			END,
			vuln_id
	`, scanID)
	if err != nil {
		return data, err
	}
	defer rows.Close()

	for rows.Next() {
		var v Vulnerability
		err := rows.Scan(&v.VulnID, &v.Severity, &v.PkgName, &v.InstalledVersion,
			&v.FixedVersion, &v.Title, &v.Description)
		if err != nil {
			return data, err
		}
		data.Vulnerabilities = append(data.Vulnerabilities, v)

		switch v.Severity {
		case "CRITICAL":
			data.Scan.Critical++
		case "HIGH":
			data.Scan.High++
		case "MEDIUM":
			data.Scan.Medium++
		case "LOW":
			data.Scan.Low++
		}
	}

	return data, rows.Err()
}

func updateMetrics(data DashboardData) {
	imagesTotal.Set(float64(data.TotalImages))
	vulnerabilities.WithLabelValues("critical").Set(float64(data.CriticalTotal))
	vulnerabilities.WithLabelValues("high").Set(float64(data.HighTotal))
	vulnerabilities.WithLabelValues("medium").Set(float64(data.MediumTotal))
	vulnerabilities.WithLabelValues("low").Set(float64(data.LowTotal))
}
