// ============================================================================
// Temporal Backup Worker
// ============================================================================
//
// Package: main
// Purpose: Long-running worker service that executes backup workflows
//
// This worker process connects to the Temporal cluster and listens for backup
// workflow executions on the "backup-task-queue". When triggered (either by
// schedule or manual dispatch), it executes the snapshot activities for Nomad,
// Consul, PostgreSQL, and the container registry.
//
// Deployment:
//   - Runs as a Nomad service job (temporal-backup-worker)
//   - Constrained to run on mccoy node (has /mnt/gdrive access)
//   - Uses Nomad workload identity to authenticate with Vault for credentials
//   - Connects to Temporal server at 192.168.68.61:7233
//
// Configuration:
//   - TEMPORAL_ADDRESS: Temporal server endpoint (default: localhost:7233)
//   - NOMAD_TOKEN: Retrieved from Vault via workload identity
//   - CONSUL_HTTP_TOKEN: Retrieved from Vault via workload identity
//   - PGPASSWORD: Retrieved from Vault via workload identity
//
// Build tags: worker (excludes trigger binary code)
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

//go:build worker
// +build worker

package main

import (
	"context"
	"log"
	"os"
	"strings"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/contrib/opentelemetry"
	"go.temporal.io/sdk/interceptor"
	"go.temporal.io/sdk/worker"
)

// initTracer initializes OpenTelemetry tracing with OTLP gRPC exporter.
// Reads OTEL_EXPORTER_OTLP_ENDPOINT from environment (defaults to tempo.service.consul:4317).
// Returns a shutdown function that should be deferred.
func initTracer(ctx context.Context) func(context.Context) error {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "tempo.service.consul:4317"
	}
	// Strip http:// or https:// prefix if present (gRPC uses host:port)
	endpoint = strings.TrimPrefix(endpoint, "http://")
	endpoint = strings.TrimPrefix(endpoint, "https://")

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		log.Printf("Warning: failed to create OTLP exporter: %v (tracing disabled)", err)
		return func(context.Context) error { return nil }
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("temporal-backup-worker"),
		),
	)
	if err != nil {
		log.Printf("Warning: failed to create resource: %v", err)
		res = resource.Default()
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	log.Printf("OpenTelemetry tracing initialized (endpoint: %s)", endpoint)
	return tp.Shutdown
}

// runWorker initializes and starts the Temporal worker process.
//
// The worker connects to the Temporal server and registers all backup-related
// workflows and activities. It runs indefinitely until interrupted (SIGTERM/SIGINT)
// or encounters a fatal error.
//
// Registered components:
//   - BackupWorkflow: Main orchestration workflow
//   - TakeNomadSnapshot: Activity to snapshot Nomad cluster
//   - TakeConsulSnapshot: Activity to snapshot Consul cluster
//   - TakePostgresBackup: Activity to backup all PostgreSQL databases
//   - TakeRegistryBackup: Activity to backup container registry data
//   - CleanupOldBackups: Activity to remove snapshots older than retention period
//   - TrivyScanWorkflow: Vulnerability scanning for container images
//   - CleanupOrphanedDataWorkflow: Cleanup orphaned job data directories from nodes
func runWorker() {
	ctx := context.Background()

	// Initialize OpenTelemetry tracing
	shutdownTracer := initTracer(ctx)
	defer shutdownTracer(ctx)

	temporalAddr := os.Getenv("TEMPORAL_ADDRESS")
	if temporalAddr == "" {
		temporalAddr = "localhost:7233"
	}

	// Create tracing interceptor for Temporal
	tracingInterceptor, err := opentelemetry.NewTracingInterceptor(opentelemetry.TracerOptions{})
	if err != nil {
		log.Printf("Warning: failed to create tracing interceptor: %v", err)
	}

	clientOpts := client.Options{
		HostPort: temporalAddr,
	}
	if tracingInterceptor != nil {
		clientOpts.Interceptors = []interceptor.ClientInterceptor{tracingInterceptor}
	}

	c, err := client.Dial(clientOpts)
	if err != nil {
		log.Fatalln("Unable to create Temporal client", err)
	}
	defer c.Close()

	w := worker.New(c, "backup-task-queue", worker.Options{})

	// Register backup workflow and activities
	w.RegisterWorkflow(BackupWorkflow)
	w.RegisterActivity(TakeNomadSnapshot)
	w.RegisterActivity(TakeConsulSnapshot)
	w.RegisterActivity(TakePostgresBackup)
	w.RegisterActivity(TakeRegistryBackup)
	w.RegisterActivity(CleanupOldBackups)
	w.RegisterActivity(UploadToS3)
	w.RegisterActivity(CleanupOldS3Backups)

	// Register trivy scanner workflow and activities
	w.RegisterWorkflow(TrivyScanWorkflow)
	w.RegisterActivity(GetRunningImages)
	w.RegisterActivity(ScanImage)
	w.RegisterActivity(SaveScanToPostgres)

	// Register orphaned data cleanup workflow and activities
	w.RegisterWorkflow(CleanupOrphanedDataWorkflow)
	w.RegisterActivity(GetAllNomadClientNodes)
	w.RegisterActivity(CleanupNodeViaSSH)

	log.Println("Temporal worker starting...")
	log.Printf("Connected to Temporal at %s", temporalAddr)
	log.Println("Listening on task queue: backup-task-queue")

	err = w.Run(worker.InterruptCh())
	if err != nil {
		log.Fatalln("Unable to start worker", err)
	}
}

func main() {
	runWorker()
}
