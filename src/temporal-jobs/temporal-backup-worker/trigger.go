// ============================================================================
// Temporal Backup Trigger
// ============================================================================
//
// Package: main
// Purpose: Initiates backup workflow execution on demand or via schedule
//
// This trigger client starts a new backup workflow execution in the Temporal
// cluster. It can be invoked manually for testing or automatically by the
// temporal-backup-trigger Nomad periodic job (daily at 2 AM).
//
// Execution flow:
//   1. Connect to Temporal server
//   2. Start BackupWorkflow with unique timestamped ID
//   3. Wait synchronously for workflow completion
//   4. Log results and exit
//
// The trigger blocks until the workflow completes, making it suitable for
// batch job execution where we want to know the outcome before terminating.
//
// Deployment:
//   - Runs as Nomad periodic batch job (temporal-backup-trigger)
//   - Can run on any node (no host volume requirements)
//   - Scheduled via cron: "0 2 * * *" (daily at 2 AM Pacific)
//
// Configuration:
//   - TEMPORAL_ADDRESS: Temporal server endpoint (default: localhost:7233)
//
// Manual execution:
//   - Local: make run-trigger
//   - Nomad: nomad job dispatch temporal-backup-trigger
//
// Build tags: trigger (excludes worker binary code)
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

package main

import (
	"context"
	"log"
	"os"
	"time"

	"go.temporal.io/sdk/client"
)

// runTrigger initiates a workflow execution and waits for completion.
//
// Creates a unique workflow ID using the current timestamp to ensure each
// run is independently tracked in the Temporal UI. The function blocks
// until the workflow completes (successfully or with error) and logs the results.
//
// Supported workflows (via WORKFLOW_NAME env var):
//   - "backup" (default): BackupWorkflow for infrastructure backups
//   - "trivy": TrivyScanWorkflow for vulnerability scanning
//
// Exit codes:
//   - 0: Workflow completed successfully
//   - 1: Failed to connect to Temporal or workflow execution failed
//
//nolint:unused // Called from trigger_main.go (build tag: trigger)
func runTrigger() {
	temporalAddr := os.Getenv("TEMPORAL_ADDRESS")
	if temporalAddr == "" {
		temporalAddr = "localhost:7233"
	}

	workflowName := os.Getenv("WORKFLOW_NAME")
	if workflowName == "" {
		workflowName = "backup"
	}

	c, err := client.Dial(client.Options{
		HostPort: temporalAddr,
	})
	if err != nil {
		log.Fatalln("Unable to create Temporal client", err)
	}
	defer c.Close()

	workflowID := workflowName + "-" + time.Now().Format("2006-01-02-15-04-05")

	workflowOptions := client.StartWorkflowOptions{
		ID:        workflowID,
		TaskQueue: "backup-task-queue",
	}

	switch workflowName {
	case "backup":
		runBackupWorkflow(c, workflowOptions)
	case "trivy":
		runTrivyWorkflow(c, workflowOptions)
	default:
		log.Fatalf("Unknown workflow: %s (supported: backup, trivy)\n", workflowName)
	}
}

// runBackupWorkflow executes the backup workflow and logs results.
//
//nolint:unused // Called from runTrigger (build tag: trigger)
func runBackupWorkflow(c client.Client, opts client.StartWorkflowOptions) {
	we, err := c.ExecuteWorkflow(context.Background(), opts, BackupWorkflow)
	if err != nil {
		log.Fatalln("Unable to start workflow", err)
	}

	log.Printf("Started backup workflow: %s (RunID: %s)\n", we.GetID(), we.GetRunID())
	log.Printf("View in UI: http://temporal.service.consul:8080/namespaces/default/workflows/%s/%s\n",
		we.GetID(), we.GetRunID())

	log.Println("Waiting for result...")
	var result BackupResult
	err = we.Get(context.Background(), &result)
	if err != nil {
		log.Fatalf("Workflow failed: %v\n", err)
	}

	log.Println("Backup complete!")
	log.Printf("  Nomad snapshot: %s", result.NomadSnapshot)
	log.Printf("  Consul snapshot: %s", result.ConsulSnapshot)
	log.Printf("  PostgreSQL backup: %s", result.PostgresBackup)
	log.Printf("  Registry backup: %s", result.RegistryBackup)
}

// runTrivyWorkflow executes the trivy scan workflow and logs results.
//
//nolint:unused // Called from runTrigger (build tag: trigger)
func runTrivyWorkflow(c client.Client, opts client.StartWorkflowOptions) {
	we, err := c.ExecuteWorkflow(context.Background(), opts, TrivyScanWorkflow)
	if err != nil {
		log.Fatalln("Unable to start workflow", err)
	}

	log.Printf("Started trivy scan workflow: %s (RunID: %s)\n", we.GetID(), we.GetRunID())
	log.Printf("View in UI: http://temporal.service.consul:8080/namespaces/default/workflows/%s/%s\n",
		we.GetID(), we.GetRunID())

	log.Println("Waiting for result...")
	err = we.Get(context.Background(), nil)
	if err != nil {
		log.Fatalf("Workflow failed: %v\n", err)
	}

	log.Println("Trivy scan complete! Check /mnt/gdrive/trivy-reports for results.")
}
