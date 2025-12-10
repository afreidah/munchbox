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
	"log"
	"os"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"
)

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
func runWorker() {
	temporalAddr := os.Getenv("TEMPORAL_ADDRESS")
	if temporalAddr == "" {
		temporalAddr = "localhost:7233"
	}

	c, err := client.Dial(client.Options{
		HostPort: temporalAddr,
	})
	if err != nil {
		log.Fatalln("Unable to create Temporal client", err)
	}
	defer c.Close()

	w := worker.New(c, "backup-task-queue", worker.Options{})

	// Register workflow and activities
	w.RegisterWorkflow(BackupWorkflow)
	w.RegisterActivity(TakeNomadSnapshot)
	w.RegisterActivity(TakeConsulSnapshot)
	w.RegisterActivity(TakePostgresBackup)
	w.RegisterActivity(TakeRegistryBackup)
	w.RegisterActivity(CleanupOldBackups)

	log.Println("Backup worker starting...")
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
