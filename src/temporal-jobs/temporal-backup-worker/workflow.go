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
	"os"
	"strconv"
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

const (
	defaultLocalRetentionDays = 7
	defaultS3RetentionDays    = 30
)

// BackupResult contains the outcome of a backup workflow execution.
type BackupResult struct {
	NomadSnapshot    string    // Path to Nomad snapshot file
	ConsulSnapshot   string    // Path to Consul snapshot file
	PostgresBackup   string    // Path to PostgreSQL dump file
	RegistryBackup   string    // Path to Registry backup file
	NomadS3Key       string    // S3 key for Nomad snapshot
	ConsulS3Key      string    // S3 key for Consul snapshot
	PostgresS3Key    string    // S3 key for PostgreSQL dump
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

	// Upload Nomad snapshot to S3
	var nomadS3Key string
	err = workflow.ExecuteActivity(quickCtx, UploadToS3, nomadPath, "backups/nomad").Get(ctx, &nomadS3Key)
	if err != nil {
		logger.Warn("Nomad S3 upload failed", "error", err)
	} else {
		result.NomadS3Key = nomadS3Key
		logger.Info("Nomad snapshot uploaded to S3", "key", nomadS3Key)
	}

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

	// Upload Consul snapshot to S3
	var consulS3Key string
	err = workflow.ExecuteActivity(quickCtx, UploadToS3, consulPath, "backups/consul").Get(ctx, &consulS3Key)
	if err != nil {
		logger.Warn("Consul S3 upload failed", "error", err)
	} else {
		result.ConsulS3Key = consulS3Key
		logger.Info("Consul snapshot uploaded to S3", "key", consulS3Key)
	}

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

	// Upload PostgreSQL backup to S3
	var pgS3Key string
	err = workflow.ExecuteActivity(longCtx, UploadToS3, pgPath, "backups/postgres").Get(ctx, &pgS3Key)
	if err != nil {
		logger.Warn("PostgreSQL S3 upload failed", "error", err)
	} else {
		result.PostgresS3Key = pgS3Key
		logger.Info("PostgreSQL backup uploaded to S3", "key", pgS3Key)
	}

	// Read retention settings from environment (deterministic via SideEffect)
	var localRetention, s3Retention int
	workflow.SideEffect(ctx, func(ctx workflow.Context) interface{} {
		return getRetentionDays("LOCAL_RETENTION_DAYS", defaultLocalRetentionDays)
	}).Get(&localRetention)
	workflow.SideEffect(ctx, func(ctx workflow.Context) interface{} {
		return getRetentionDays("S3_RETENTION_DAYS", defaultS3RetentionDays)
	}).Get(&s3Retention)

	// Clean up old local backups
	logger.Info("Cleaning up old local backups", "retention_days", localRetention)
	err = workflow.ExecuteActivity(quickCtx, CleanupOldBackups, localRetention).Get(ctx, nil)
	if err != nil {
		logger.Warn("Local cleanup failed", "error", err)
	}

	// Clean up old S3 backups
	logger.Info("Cleaning up old S3 backups", "retention_days", s3Retention)
	err = workflow.ExecuteActivity(quickCtx, CleanupOldS3Backups, s3Retention).Get(ctx, nil)
	if err != nil {
		logger.Warn("S3 cleanup failed", "error", err)
	}

	result.Success = true
	logger.Info("Backup workflow complete")
	return result, nil
}

// getRetentionDays reads a retention period from an environment variable.
// Returns the default value if the variable is unset or not a valid integer.
func getRetentionDays(envVar string, defaultDays int) int {
	val := os.Getenv(envVar)
	if val == "" {
		return defaultDays
	}
	days, err := strconv.Atoi(val)
	if err != nil || days < 1 {
		return defaultDays
	}
	return days
}
