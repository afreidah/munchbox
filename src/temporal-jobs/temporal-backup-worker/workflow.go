// ============================================================================
// Temporal Backup Workflow
// ============================================================================
//
// Package: main
// Purpose: Orchestrates scheduled backups of Munchbox infrastructure
//
// This workflow coordinates the creation of snapshots for:
//   - Nomad cluster state (job specs, allocations, ACLs)
//   - Consul cluster state (KV store, services, ACLs + Vault data)
//   - PostgreSQL databases (authentik, nextcloud, temporal)
//   - Container registry images
//
// Note: Vault uses Consul as its storage backend, so Vault data is included
// in the Consul snapshot. No separate Vault snapshot is needed.
//
// Snapshots are stored in /mnt/gdrive with 7-day retention.
//
// Execution:
//   - Triggered by temporal-backup-trigger Nomad job (daily at 2 AM)
//   - Executed by temporal-backup-worker
//   - Each activity has timeout with exponential retry (3 attempts)
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
	NomadSnapshot    string    // Path to Nomad snapshot file
	ConsulSnapshot   string    // Path to Consul snapshot file
	PostgresBackup   string    // Path to PostgreSQL dump file
	RegistryBackup   string    // Path to Registry backup file
	Timestamp        time.Time // When the backup workflow started
	Success          bool      // Whether all backups completed successfully
	Error            string    // Error message if any backup failed
}

// BackupWorkflow orchestrates the backup of Munchbox infrastructure.
//
// The workflow executes snapshot activities sequentially, followed by cleanup.
// If any snapshot fails, the workflow terminates immediately and returns an error.
// Cleanup failures are logged but do not fail the workflow.
//
// Activities are configured with:
//   - 5-minute timeout for quick snapshots (Nomad, Consul)
//   - 30-minute timeout for large backups (PostgreSQL, Registry)
//   - Exponential backoff retry (1s, 2s, 4s...)
//   - Maximum 3 retry attempts
//
// Returns:
//   - *BackupResult: Summary of backup execution with file paths
//   - error: Non-nil if any critical backup activity fails
func BackupWorkflow(ctx workflow.Context) (*BackupResult, error) {
	logger := workflow.GetLogger(ctx)
	logger.Info("Starting backup workflow")

	// Configure activity execution options for quick snapshots
	quickOpts := workflow.ActivityOptions{
		StartToCloseTimeout: 5 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    time.Minute,
			MaximumAttempts:    3,
		},
	}

	// Configure activity execution options for large backups
	longOpts := workflow.ActivityOptions{
		StartToCloseTimeout: 30 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    time.Minute,
			MaximumAttempts:    3,
		},
	}

	result := &BackupResult{
		Timestamp: workflow.Now(ctx),
	}

	// Take Nomad snapshot
	quickCtx := workflow.WithActivityOptions(ctx, quickOpts)
	logger.Info("Taking Nomad snapshot")
	var nomadPath string
	err := workflow.ExecuteActivity(quickCtx, TakeNomadSnapshot).Get(ctx, &nomadPath)
	if err != nil {
		logger.Error("Nomad backup failed", "error", err)
		result.Error = "Nomad backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.NomadSnapshot = nomadPath
	logger.Info("Nomad snapshot complete", "path", nomadPath)

	// Take Consul snapshot (includes Vault data)
	logger.Info("Taking Consul snapshot")
	var consulPath string
	err = workflow.ExecuteActivity(quickCtx, TakeConsulSnapshot).Get(ctx, &consulPath)
	if err != nil {
		logger.Error("Consul backup failed", "error", err)
		result.Error = "Consul backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.ConsulSnapshot = consulPath
	logger.Info("Consul snapshot complete", "path", consulPath)

	// Take PostgreSQL backup (all databases)
	longCtx := workflow.WithActivityOptions(ctx, longOpts)
	logger.Info("Taking PostgreSQL backup")
	var pgPath string
	err = workflow.ExecuteActivity(longCtx, TakePostgresBackup).Get(ctx, &pgPath)
	if err != nil {
		logger.Error("PostgreSQL backup failed", "error", err)
		result.Error = "PostgreSQL backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.PostgresBackup = pgPath
	logger.Info("PostgreSQL backup complete", "path", pgPath)

	// Take Registry backup
	logger.Info("Taking Registry backup")
	var registryPath string
	err = workflow.ExecuteActivity(longCtx, TakeRegistryBackup).Get(ctx, &registryPath)
	if err != nil {
		logger.Error("Registry backup failed", "error", err)
		result.Error = "Registry backup failed: " + err.Error()
		result.Success = false
		return result, err
	}
	result.RegistryBackup = registryPath
	logger.Info("Registry backup complete", "path", registryPath)

	// Clean up old backups (keep last 7 days)
	logger.Info("Cleaning up old backups")
	err = workflow.ExecuteActivity(quickCtx, CleanupOldBackups, 7).Get(ctx, nil)
	if err != nil {
		// Log but don't fail - cleanup is non-critical
		logger.Warn("Cleanup failed", "error", err)
	}

	result.Success = true
	logger.Info("Backup workflow complete")
	return result, nil
}
