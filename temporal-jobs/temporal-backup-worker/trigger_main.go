// ============================================================================
// Temporal Backup Trigger - Main Entry Point
// ============================================================================
//
// Package: main
// Purpose: Entry point for the backup trigger binary
//
// This file provides the main() function for the trigger binary, which is
// built separately from the worker binary using Go build tags. The trigger
// is a short-lived process that initiates a backup workflow and exits after
// completion or failure.
//
// Build tags: trigger
//   - Ensures only trigger-specific code is included in this binary
//   - Worker code is excluded via the "worker" build tag
//
// Usage:
//   - Automated: Invoked by temporal-backup-trigger Nomad periodic job
//   - Manual: ./bin/trigger or make run-trigger
//
// The actual trigger logic is implemented in trigger.go (runTrigger function).
// This separation allows both worker and trigger to share common workflow
// definitions while producing distinct executables.
//
// Author: Alex
// Repository: munchbox/temporal-backup-worker
// ============================================================================

//go:build trigger
// +build trigger

package main

func main() {
	runTrigger()
}
