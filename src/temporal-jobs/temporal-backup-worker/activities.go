// ============================================================================
// Temporal Backup Activities
// ============================================================================
//
// Package: main
// Purpose: Implements Temporal activities for Munchbox infrastructure backups
//
// This file contains the actual backup operations executed by the worker when
// the BackupWorkflow is triggered. Each activity is a discrete unit of work
// that can be retried independently according to the workflow's retry policy.
//
// Activities:
//   - TakeNomadSnapshot: Creates Raft snapshot of Nomad cluster state
//   - TakeConsulSnapshot: Creates Raft snapshot of Consul cluster state (includes Vault)
//   - TakePostgresBackup: Dumps all PostgreSQL databases (pg_dumpall)
//   - TakeRegistryBackup: Creates tarball of container registry data
//   - CleanupOldBackups: Removes snapshots older than retention period
//
// Storage:
//   All snapshots are stored on /mnt/gdrive (Google Drive mount) for:
//   - Persistence across node failures
//   - Automatic cloud backup via rclone
//   - Centralized backup location
//
// Naming convention:
//   {service}-{timestamp}.{ext} (e.g., nomad-20251030020000.snap)
//
// Retention:
//   Snapshots older than 7 days are automatically removed during cleanup.
//   Retention period is configurable in the workflow execution.
//
// Authentication:
//   Activities use environment variables for service authentication:
//   - NOMAD_TOKEN: From Vault via workload identity
//   - CONSUL_HTTP_TOKEN: From Vault via workload identity
//   - PGPASSWORD: From Vault via workload identity
//
// Error handling:
//   - Failed snapshots return errors to the workflow for retry
//   - Cleanup failures are logged but don't fail the workflow
//   - File operation errors include detailed context for debugging
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"go.temporal.io/sdk/activity"
)

const (
	nomadBackupDir    = "/mnt/gdrive/nomad-snapshots"
	consulBackupDir   = "/mnt/gdrive/consul-snapshots"
	postgresBackupDir = "/mnt/gdrive/postgres-backups"
	registryBackupDir = "/mnt/gdrive/registry-backups"
	registryDataDir   = "/mnt/gdrive/munchbox-data/registry"
)

// TakeNomadSnapshot creates a Raft snapshot of the Nomad cluster.
//
// This captures the complete state of the Nomad cluster including:
//   - All job specifications and their history
//   - Node registrations and attributes
//   - ACL tokens and policies
//   - Evaluations and allocations
//   - Scheduler configuration
//
// The snapshot can be used to restore Nomad cluster state after a disaster.
// Requires NOMAD_TOKEN with snapshot permissions.
//
// Returns:
//   - string: Full path to the created snapshot file
//   - error: Non-nil if snapshot creation fails
func TakeNomadSnapshot(ctx context.Context) (string, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Starting Nomad snapshot")

	// Ensure backup directory exists
	if err := os.MkdirAll(nomadBackupDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create backup dir: %w", err)
	}

	timestamp := time.Now().Format("20060102150405")
	filename := filepath.Join(nomadBackupDir, fmt.Sprintf("nomad-%s.snap", timestamp))

	cmd := exec.CommandContext(ctx, "nomad", "operator", "snapshot", "save", filename)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("nomad snapshot failed: %w, output: %s", err, output)
	}

	// Get file size for logging
	info, _ := os.Stat(filename)
	logger.Info("Nomad snapshot saved", "path", filename, "size_bytes", info.Size())

	return filename, nil
}

// TakeConsulSnapshot creates a Raft snapshot of the Consul cluster.
//
// This captures the complete state of the Consul cluster including:
//   - All KV store data (configs, secrets, service metadata)
//   - Service catalog and health check registrations
//   - ACL tokens, policies, and roles
//   - Sessions and prepared queries
//   - Intentions (service mesh authorization)
//
// The snapshot can be used to restore Consul cluster state after a disaster.
// Requires CONSUL_HTTP_TOKEN with snapshot permissions.
//
// Returns:
//   - string: Full path to the created snapshot file
//   - error: Non-nil if snapshot creation fails
func TakeConsulSnapshot(ctx context.Context) (string, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Starting Consul snapshot")

	// Ensure backup directory exists
	if err := os.MkdirAll(consulBackupDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create backup dir: %w", err)
	}

	timestamp := time.Now().Format("20060102150405")
	filename := filepath.Join(consulBackupDir, fmt.Sprintf("consul-%s.snap", timestamp))

	cmd := exec.CommandContext(ctx, "consul", "snapshot", "save", filename)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("consul snapshot failed: %w, output: %s", err, output)
	}

	// Get file size for logging
	info, _ := os.Stat(filename)
	logger.Info("Consul snapshot saved", "path", filename, "size_bytes", info.Size())

	return filename, nil
}

// TakePostgresBackup creates a full dump of all PostgreSQL databases.
//
// This captures all databases in postgres-shared including:
//   - authentik (SSO/authentication)
//   - nextcloud (file sharing)
//   - temporal / temporal_visibility (workflow engine)
//
// Uses pg_dumpall for a complete backup including roles and permissions.
// The dump is compressed with gzip for storage efficiency.
//
// Requires PGPASSWORD environment variable set.
//
// Returns:
//   - string: Full path to the created dump file
//   - error: Non-nil if dump creation fails
func TakePostgresBackup(ctx context.Context) (string, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Starting PostgreSQL backup")

	// Ensure backup directory exists
	if err := os.MkdirAll(postgresBackupDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create backup dir: %w", err)
	}

	timestamp := time.Now().Format("20060102150405")
	filename := filepath.Join(postgresBackupDir, fmt.Sprintf("postgres-%s.sql.gz", timestamp))

	// Create the dump command piped to gzip
	// Use bash with pipefail so we catch pg_dumpall errors even when piped to gzip
	cmd := exec.CommandContext(ctx, "bash", "-c",
		fmt.Sprintf("set -o pipefail; pg_dumpall -h postgres-primary.service.consul -U postgres | gzip > %s", filename))

	cmd.Env = append(os.Environ(),
		"PGPASSWORD="+os.Getenv("PGPASSWORD"),
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("postgres backup failed: %w, output: %s", err, output)
	}

	// Get file size for logging
	info, _ := os.Stat(filename)
	logger.Info("PostgreSQL backup saved", "path", filename, "size_bytes", info.Size())

	return filename, nil
}

// TakeRegistryBackup creates a tarball of the container registry data.
//
// This captures all container images stored in the local registry including:
//   - All pushed Docker images
//   - Image layers and manifests
//   - Registry metadata
//
// The backup is compressed with gzip for storage efficiency.
//
// Returns:
//   - string: Full path to the created tarball
//   - error: Non-nil if backup creation fails
func TakeRegistryBackup(ctx context.Context) (string, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Starting Registry backup")

	// Ensure backup directory exists
	if err := os.MkdirAll(registryBackupDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create backup dir: %w", err)
	}

	timestamp := time.Now().Format("20060102150405")
	filename := filepath.Join(registryBackupDir, fmt.Sprintf("registry-%s.tar.gz", timestamp))

	// Create tarball of registry data
	cmd := exec.CommandContext(ctx, "tar", "-czf", filename, "-C", filepath.Dir(registryDataDir), filepath.Base(registryDataDir))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("registry backup failed: %w, output: %s", err, output)
	}

	// Get file size for logging
	info, _ := os.Stat(filename)
	logger.Info("Registry backup saved", "path", filename, "size_bytes", info.Size())

	return filename, nil
}

// CleanupOldBackups removes snapshot files older than the retention period.
//
// This activity prevents unbounded growth of backup storage by automatically
// removing old snapshots. Only files with .snap extension are considered for
// deletion, protecting other files that may exist in the backup directories.
//
// The cleanup process:
//  1. Scans all three backup directories (Nomad, Consul, Vault)
//  2. Identifies .snap files older than the retention period
//  3. Attempts to delete each old snapshot
//  4. Logs success/failure for each deletion attempt
//
// Cleanup failures do not fail the workflow - they are logged as warnings.
// This ensures that backup creation continues even if cleanup encounters issues.
//
// Parameters:
//   - retentionDays: Number of days to retain snapshots (typically 7)
//
// Returns:
//   - error: Non-nil if directory scanning fails (deletion errors are logged only)
func CleanupOldBackups(ctx context.Context, retentionDays int) error {
	logger := activity.GetLogger(ctx)
	logger.Info("Cleaning up old backups", "retention_days", retentionDays)

	cutoff := time.Now().AddDate(0, 0, -retentionDays)

	// Clean Nomad backups
	if err := cleanupDirectory(nomadBackupDir, cutoff, logger); err != nil {
		return fmt.Errorf("failed to cleanup nomad backups: %w", err)
	}

	// Clean Consul backups
	if err := cleanupDirectory(consulBackupDir, cutoff, logger); err != nil {
		return fmt.Errorf("failed to cleanup consul backups: %w", err)
	}

	// Clean PostgreSQL backups
	if err := cleanupDirectory(postgresBackupDir, cutoff, logger); err != nil {
		return fmt.Errorf("failed to cleanup postgres backups: %w", err)
	}

	// Clean Registry backups
	if err := cleanupDirectory(registryBackupDir, cutoff, logger); err != nil {
		return fmt.Errorf("failed to cleanup registry backups: %w", err)
	}

	return nil
}

// cleanupDirectory removes backup files older than cutoff time from a directory.
//
// Helper function that performs the actual cleanup logic for a single directory.
// Handles various backup file extensions (.snap, .sql.gz, .tar.gz).
// Skips subdirectories. Deletion failures are logged but do not stop the cleanup process.
//
// Parameters:
//   - dir: Path to the directory to clean
//   - cutoff: Time before which backups should be deleted
//   - logger: Temporal activity logger for status messages
//
// Returns:
//   - error: Non-nil only if the directory cannot be read
func cleanupDirectory(dir string, cutoff time.Time, logger interface {
	Info(string, ...interface{})
	Warn(string, ...interface{})
},
) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		// Directory may not exist yet if no backups have been taken
		if os.IsNotExist(err) {
			logger.Info("Backup directory does not exist, skipping cleanup", "dir", dir)
			return nil
		}
		return fmt.Errorf("failed to read dir %s: %w", dir, err)
	}

	deleted := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		// Check for backup file extensions
		name := entry.Name()
		isBackup := filepath.Ext(name) == ".snap" ||
			strings.HasSuffix(name, ".sql.gz") ||
			strings.HasSuffix(name, ".tar.gz")
		if !isBackup {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			logger.Warn("Failed to stat file", "file", entry.Name(), "error", err)
			continue
		}

		if info.ModTime().Before(cutoff) {
			path := filepath.Join(dir, entry.Name())
			if err := os.Remove(path); err != nil {
				logger.Warn("Failed to remove old backup", "path", path, "error", err)
			} else {
				logger.Info("Removed old backup", "path", path, "age_days", int(time.Since(info.ModTime()).Hours()/24))
				deleted++
			}
		}
	}

	logger.Info("Cleanup complete for directory", "dir", dir, "deleted_count", deleted)
	return nil
}
