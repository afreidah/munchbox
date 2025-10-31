// ============================================================================
// Temporal Backup Workflow
// ============================================================================
//
// Package: main
// Purpose: Orchestrates scheduled backups of HashiCorp infrastructure
//
// This workflow coordinates the creation of snapshots for:
//   - Nomad cluster state (job specs, allocations, ACLs)
//   - Consul cluster state (KV store, services, ACLs)
//   - OpenBao cluster state (secrets, policies, auth methods)
//
// Snapshots are stored in /mnt/gdrive with 7-day retention.
//
// Execution:
//   - Triggered by temporal-backup-trigger Nomad job (daily at 2 AM)
//   - Executed by temporal-backup-worker running on mccoy
//   - Each activity has 5-minute timeout with exponential retry (3 attempts)
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

package main

import (
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

// BackupResult contains the outcome of a backup workflow execution.
type BackupResult struct {
	NomadSnapshot   string    // Path to Nomad snapshot file
	ConsulSnapshot  string    // Path to Consul snapshot file
	OpenbaoSnapshot string    // Path to OpenBao snapshot file
	Timestamp       time.Time // When the backup workflow started
	Success         bool      // Whether all backups completed successfully
	Error           string    // Error message if any backup failed
}

// BackupWorkflow orchestrates the backup of Nomad, Consul, and OpenBao clusters.
//
// The workflow executes three snapshot activities sequentially, followed by cleanup.
// If any snapshot fails, the workflow terminates immediately and returns an error.
// Cleanup failures are logged but do not fail the workflow.
//
// Activities are configured with:
//   - 5-minute timeout per activity
//   - Exponential backoff retry (1s, 2s, 4s...)
//   - Maximum 3 retry attempts
//
// Returns:
//   - *BackupResult: Summary of backup execution with file paths
//   - error: Non-nil if any critical backup activity fails
func BackupWorkflow(ctx workflow.Context) (*BackupResult, error) {
	logger := workflow.GetLogger(ctx)
	logger.Info("Starting backup workflow")

	// Configure activity execution options
	opts := workflow.ActivityOptions{
		StartToCloseTimeout: 5 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    time.Minute,
			MaximumAttempts:    3,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, opts)

	result := &BackupResult{
		Timestamp: workflow.Now(ctx),
	}

	// Take Nomad snapshot
	logger.Info("Taking Nomad snapshot")
	var nomadPath string
	err := workflow.ExecuteActivity(ctx, TakeNomadSnapshot).Get(ctx, &nomadPath)
	if err != nil {
		logger.Error("Nomad backup failed", "error", err)
		result.Error = "Nomad backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.NomadSnapshot = nomadPath
	logger.Info("Nomad snapshot complete", "path", nomadPath)

	// Take Consul snapshot
	logger.Info("Taking Consul snapshot")
	var consulPath string
	err = workflow.ExecuteActivity(ctx, TakeConsulSnapshot).Get(ctx, &consulPath)
	if err != nil {
		logger.Error("Consul backup failed", "error", err)
		result.Error = "Consul backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.ConsulSnapshot = consulPath
	logger.Info("Consul snapshot complete", "path", consulPath)

	// Take OpenBao snapshot
	logger.Info("Taking OpenBao snapshot")
	var openbaoPath string
	err = workflow.ExecuteActivity(ctx, TakeOpenbaoSnapshot).Get(ctx, &openbaoPath)
	if err != nil {
		logger.Error("OpenBao backup failed", "error", err)
		result.Error = "OpenBao backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.OpenbaoSnapshot = openbaoPath
	logger.Info("OpenBao snapshot complete", "path", openbaoPath)

	// Clean up old backups (keep last 7 days)
	logger.Info("Cleaning up old backups")
	err = workflow.ExecuteActivity(ctx, CleanupOldBackups, 7).Get(ctx, nil)
	if err != nil {
		// Log but don't fail - cleanup is non-critical
		logger.Warn("Cleanup failed", "error", err)
	}

	result.Success = true
	logger.Info("Backup workflow complete")
	return result, nil
}
