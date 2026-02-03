// ============================================================================
// Orphaned Data Cleanup Workflow
// ============================================================================
//
// Package: main
// Purpose: Cleans up orphaned job data directories from all Nomad client nodes
//
// When Nomad jobs move between nodes, their ephemeral data directories may
// remain on the old nodes. This workflow SSHes to each client node and removes
// directories that don't correspond to any running allocation on that node.
//
// Safety features:
//   - DryRun mode (default: true) - set to false to actually delete
//   - Grace period - only deletes directories older than N days (default: 7)
//   - Excludes system directories (alloc, plugins, etc.)
//   - Only checks allocations running on each specific node
//
// Activities:
//   - GetAllNomadClientNodes: Retrieves list of all Nomad client nodes
//   - CleanupNodeViaSSH: SSHes to a node and performs cleanup
//
// Author: Alex Freidah
// Repository: munchbox/temporal-backup-worker
// ============================================================================
package main

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/hashicorp/nomad/api"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.temporal.io/sdk/activity"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
	"golang.org/x/crypto/ssh"
)

// CleanupConfig holds configuration for the cleanup workflow
type CleanupConfig struct {
	DataDir      string // Base directory to scan (default: /opt/nomad/data)
	GraceDays    int    // Only delete directories older than this many days (default: 7)
	DryRun       bool   // If true, only report what would be deleted
	DockerPrune  bool   // If true, also prune unused Docker images
}

// CleanupResult holds the result of a cleanup operation
type CleanupResult struct {
	NodeName          string
	NodeAddr          string
	Scanned           int
	Orphaned          int
	Deleted           int
	Skipped           int
	DockerSpaceFreed  string // Space reclaimed by docker prune (e.g., "1.2GB")
	Errors            []string
	Output            string // Raw output from the cleanup script
}

// NodeInfo contains information about a Nomad client node
type NodeInfo struct {
	ID       string
	Name     string
	Address  string
	HTTPAddr string // Nomad agent's HTTP address (e.g., "10.200.0.11:4646")
	IsOracle bool   // Oracle nodes use ubuntu user instead of root
}

// CleanupOrphanedDataWorkflow cleans up orphaned job data directories on all Nomad client nodes.
// It queries Nomad for all client nodes, then SSHes to each one to perform cleanup.
func CleanupOrphanedDataWorkflow(ctx workflow.Context, config CleanupConfig) ([]CleanupResult, error) {
	logger := workflow.GetLogger(ctx)
	logger.Info("Starting orphaned data cleanup workflow",
		"dataDir", config.DataDir,
		"graceDays", config.GraceDays,
		"dryRun", config.DryRun,
		"dockerPrune", config.DockerPrune)

	// Set defaults
	if config.DataDir == "" {
		config.DataDir = "/opt/nomad/data"
	}
	if config.GraceDays == 0 {
		config.GraceDays = 7
	}

	ao := workflow.ActivityOptions{
		StartToCloseTimeout: 10 * time.Minute,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 2.0,
			MaximumInterval:    time.Minute,
			MaximumAttempts:    3,
		},
	}
	ctx = workflow.WithActivityOptions(ctx, ao)

	// Get all Nomad client nodes
	var nodes []NodeInfo
	err := workflow.ExecuteActivity(ctx, GetAllNomadClientNodes).Get(ctx, &nodes)
	if err != nil {
		return nil, fmt.Errorf("failed to get Nomad nodes: %w", err)
	}

	logger.Info("Found Nomad client nodes", "count", len(nodes))

	// Clean up each node via SSH
	var results []CleanupResult
	for _, node := range nodes {
		logger.Info("Cleaning up node", "node", node.Name, "address", node.Address)

		var result CleanupResult
		err := workflow.ExecuteActivity(ctx, CleanupNodeViaSSH, node, config).Get(ctx, &result)
		if err != nil {
			logger.Error("Failed to cleanup node", "node", node.Name, "error", err)
			result = CleanupResult{
				NodeName: node.Name,
				NodeAddr: node.Address,
				Errors:   []string{err.Error()},
			}
		}
		results = append(results, result)
	}

	// Log summary
	totalOrphaned := 0
	totalDeleted := 0
	for _, r := range results {
		totalOrphaned += r.Orphaned
		totalDeleted += r.Deleted
	}

	logger.Info("Cleanup workflow complete",
		"nodes", len(results),
		"totalOrphaned", totalOrphaned,
		"totalDeleted", totalDeleted,
		"dryRun", config.DryRun)

	return results, nil
}

// newNomadClient creates a configured Nomad API client
func newNomadClient() (*api.Client, error) {
	nomadAddr := os.Getenv("NOMAD_ADDR")
	if nomadAddr == "" {
		nomadAddr = "https://nomad.service.consul:4646"
	}

	config := api.DefaultConfig()
	config.Address = nomadAddr

	if token := os.Getenv("NOMAD_TOKEN"); token != "" {
		config.SecretID = token
	}
	if caCert := os.Getenv("NOMAD_CACERT"); caCert != "" {
		config.TLSConfig.CACert = caCert
	}

	// Wrap HTTP transport with OpenTelemetry instrumentation
	config.HttpClient = &http.Client{
		Transport: otelhttp.NewTransport(
			http.DefaultTransport,
			otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
				return fmt.Sprintf("nomad.%s", r.URL.Path)
			}),
		),
	}

	return api.NewClient(config)
}

// GetAllNomadClientNodes retrieves all Nomad client nodes
func GetAllNomadClientNodes(ctx context.Context) ([]NodeInfo, error) {
	logger := activity.GetLogger(ctx)
	logger.Info("Retrieving all Nomad client nodes")

	client, err := newNomadClient()
	if err != nil {
		return nil, fmt.Errorf("failed to create Nomad client: %w", err)
	}

	nodeList, _, err := client.Nodes().List(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list nodes: %w", err)
	}

	var nodes []NodeInfo
	for _, n := range nodeList {
		if n.Status != "ready" {
			logger.Info("Skipping node - not ready", "node", n.Name, "status", n.Status)
			continue
		}

		// Get full node info to get the address
		node, _, err := client.Nodes().Info(n.ID, nil)
		if err != nil {
			logger.Warn("Failed to get node info", "node", n.Name, "error", err)
			continue
		}

		// Determine the SSH address - use the node's address
		addr := node.Attributes["unique.network.ip-address"]
		if addr == "" {
			// Fallback to HTTPAddr
			addr = node.HTTPAddr
			// Strip port if present
			if idx := strings.LastIndex(addr, ":"); idx != -1 {
				addr = addr[:idx]
			}
		}

		// Check if this is an Oracle node (they use ubuntu user)
		isOracle := strings.HasPrefix(n.Name, "oracle")

		nodes = append(nodes, NodeInfo{
			ID:       n.ID,
			Name:     n.Name,
			Address:  addr,
			HTTPAddr: node.HTTPAddr, // e.g., "10.200.0.11:4646"
			IsOracle: isOracle,
		})
	}

	logger.Info("Found client nodes", "count", len(nodes))
	return nodes, nil
}

// CleanupNodeViaSSH SSHes to a node and performs orphaned data cleanup
func CleanupNodeViaSSH(ctx context.Context, node NodeInfo, config CleanupConfig) (CleanupResult, error) {
	logger := activity.GetLogger(ctx)
	result := CleanupResult{
		NodeName: node.Name,
		NodeAddr: node.Address,
	}

	logger.Info("Connecting to node via SSH", "node", node.Name, "address", node.Address)

	// Determine SSH user
	sshUser := "root"
	if node.IsOracle {
		sshUser = "ubuntu"
	}

	// Read SSH private key
	sshKeyPath := os.Getenv("SSH_KEY_PATH")
	if sshKeyPath == "" {
		sshKeyPath = "/root/.ssh/id_ed25519"
	}

	keyData, err := os.ReadFile(sshKeyPath)
	if err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("failed to read SSH key: %v", err))
		return result, err
	}

	signer, err := ssh.ParsePrivateKey(keyData)
	if err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("failed to parse SSH key: %v", err))
		return result, err
	}

	// SSH client config
	sshConfig := &ssh.ClientConfig{
		User: sshUser,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // TODO: Use known_hosts in production
		Timeout:         30 * time.Second,
	}

	// Connect to the node
	sshAddr := fmt.Sprintf("%s:22", node.Address)
	client, err := ssh.Dial("tcp", sshAddr, sshConfig)
	if err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("failed to connect via SSH: %v", err))
		return result, err
	}
	defer client.Close()

	// Build the cleanup script
	// For Oracle nodes, we need sudo
	sudoPrefix := ""
	if node.IsOracle {
		sudoPrefix = "sudo "
	}

	// Get Nomad token for API authentication
	nomadToken := os.Getenv("NOMAD_TOKEN")

	script := buildCleanupScript(node.ID, node.HTTPAddr, config.DataDir, config.GraceDays, config.DryRun, config.DockerPrune, sudoPrefix, nomadToken)

	// Execute the script
	session, err := client.NewSession()
	if err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("failed to create SSH session: %v", err))
		return result, err
	}
	defer session.Close()

	var stdout, stderr bytes.Buffer
	session.Stdout = &stdout
	session.Stderr = &stderr

	logger.Info("Executing cleanup script on node", "node", node.Name)
	err = session.Run(script)
	if err != nil {
		result.Errors = append(result.Errors, fmt.Sprintf("script failed: %v, stderr: %s", err, stderr.String()))
		return result, err
	}

	result.Output = stdout.String()

	// Parse the output to extract counts
	parseCleanupOutput(&result, stdout.String())

	logger.Info("Node cleanup complete",
		"node", node.Name,
		"scanned", result.Scanned,
		"orphaned", result.Orphaned,
		"deleted", result.Deleted,
		"skipped", result.Skipped)

	return result, nil
}

// buildCleanupScript generates a shell script to run on the remote node
func buildCleanupScript(nodeID, httpAddr, dataDir string, graceDays int, dryRun, dockerPrune bool, sudoPrefix, nomadToken string) string {
	dryRunFlag := "true"
	if !dryRun {
		dryRunFlag = "false"
	}
	dockerPruneFlag := "false"
	if dockerPrune {
		dockerPruneFlag = "true"
	}

	// This script runs on the remote node and:
	// 1. Queries the local Nomad agent for running allocations
	// 2. Scans the data directory
	// 3. Compares and identifies orphaned directories
	// 4. Optionally deletes them
	return fmt.Sprintf(`#!/bin/bash
set -e

DATA_DIR="%s"
GRACE_DAYS=%d
DRY_RUN="%s"
DOCKER_PRUNE="%s"
NODE_ID="%s"
NOMAD_TOKEN="%s"
NOMAD_HTTP_ADDR="%s"

# Counters
SCANNED=0
ORPHANED=0
DELETED=0
SKIPPED=0
DOCKER_SPACE_FREED="0B"

# System directories to never delete
EXCLUDE="alloc plugins tmp server client"

# Get running job IDs from local Nomad agent (use node's actual HTTP address)
# Try multiple CA cert paths for compatibility across different node types
NOMAD_CA=""
for ca in /etc/nomad.d/tls/ca.crt /opt/nomad/tls/vault-intermediate-ca.pem; do
  if [ -f "$ca" ]; then
    NOMAD_CA="$ca"
    break
  fi
done

if [ -z "$NOMAD_CA" ]; then
  echo "WARNING: Could not find Nomad CA certificate"
  echo "RESULT: scanned=0 orphaned=0 deleted=0 skipped=0"
  exit 0
fi

RUNNING_JOBS=$(%scurl -sf --cacert "$NOMAD_CA" \
  -H "X-Nomad-Token: $NOMAD_TOKEN" \
  "https://${NOMAD_HTTP_ADDR}/v1/node/${NODE_ID}/allocations" 2>/dev/null | \
  %sjq -r '.[] | select(.ClientStatus == "running") | .JobID' 2>/dev/null | sort -u || echo "")

if [ -z "$RUNNING_JOBS" ]; then
  echo "WARNING: Could not get running jobs from local Nomad agent"
  echo "RESULT: scanned=0 orphaned=0 deleted=0 skipped=0"
  exit 0
fi

echo "Running jobs on this node:"
echo "$RUNNING_JOBS" | sed 's/^/  - /'
echo ""

# Function to strip index suffix (e.g., patroni-0 -> patroni)
strip_index() {
  echo "$1" | sed 's/-[0-9]*$//'
}

# Function to check if job is running
is_running() {
  local dir="$1"
  local base=$(strip_index "$dir")
  echo "$RUNNING_JOBS" | grep -qx "$dir" && return 0
  echo "$RUNNING_JOBS" | grep -qx "$base" && return 0
  return 1
}

# Scan the data directory
for dir in "$DATA_DIR"/*/; do
  [ -d "$dir" ] || continue

  dirname=$(basename "$dir")
  SCANNED=$((SCANNED + 1))

  # Skip excluded directories
  if echo "$EXCLUDE" | grep -qw "$dirname"; then
    echo "SKIP (system): $dirname"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check if job is running
  if is_running "$dirname"; then
    echo "OK (active): $dirname"
    continue
  fi

  # Check modification time
  mtime=$(%sstat -c %%Y "$dir" 2>/dev/null || echo 0)
  now=$(date +%%s)
  age_days=$(( (now - mtime) / 86400 ))

  if [ "$age_days" -lt "$GRACE_DAYS" ]; then
    echo "SKIP (${age_days}d old, grace=${GRACE_DAYS}d): $dirname"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Get directory size
  size=$(%sdu -sh "$dir" 2>/dev/null | cut -f1 || echo "?")

  ORPHANED=$((ORPHANED + 1))

  if [ "$DRY_RUN" = "true" ]; then
    echo "WOULD DELETE (${age_days}d old, $size): $dirname"
  else
    echo "DELETING (${age_days}d old, $size): $dirname"
    %srm -rf "$dir"
    DELETED=$((DELETED + 1))
  fi
done

echo ""

# Docker image cleanup
if [ "$DOCKER_PRUNE" = "true" ]; then
  echo "=== Docker Cleanup ==="
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would prune unused Docker images (dry run)"
    # Show what would be removed
    %sdocker system df 2>/dev/null || echo "Docker not available"
  else
    # Prune unused images, containers, networks, and build cache
    # -a removes all unused images, not just dangling ones
    # -f skips confirmation prompt
    PRUNE_OUTPUT=$(%sdocker system prune -af 2>&1 || echo "Docker prune failed")
    echo "$PRUNE_OUTPUT"
    # Extract space reclaimed (format: "Total reclaimed space: 1.234GB")
    DOCKER_SPACE_FREED=$(echo "$PRUNE_OUTPUT" | grep -oP 'Total reclaimed space: \K[0-9.]+[A-Za-z]+' || echo "0B")
  fi
fi

echo ""
echo "RESULT: scanned=$SCANNED orphaned=$ORPHANED deleted=$DELETED skipped=$SKIPPED docker_freed=$DOCKER_SPACE_FREED"
`, dataDir, graceDays, dryRunFlag, dockerPruneFlag, nodeID, nomadToken, httpAddr, sudoPrefix, sudoPrefix, sudoPrefix, sudoPrefix, sudoPrefix, sudoPrefix, sudoPrefix)
}

// parseCleanupOutput extracts counts from the cleanup script output
func parseCleanupOutput(result *CleanupResult, output string) {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "RESULT:") {
			// Parse: RESULT: scanned=X orphaned=Y deleted=Z skipped=W docker_freed=XGB
			parts := strings.Fields(line)
			for _, part := range parts {
				if strings.HasPrefix(part, "scanned=") {
					fmt.Sscanf(part, "scanned=%d", &result.Scanned)
				} else if strings.HasPrefix(part, "orphaned=") {
					fmt.Sscanf(part, "orphaned=%d", &result.Orphaned)
				} else if strings.HasPrefix(part, "deleted=") {
					fmt.Sscanf(part, "deleted=%d", &result.Deleted)
				} else if strings.HasPrefix(part, "skipped=") {
					fmt.Sscanf(part, "skipped=%d", &result.Skipped)
				} else if strings.HasPrefix(part, "docker_freed=") {
					result.DockerSpaceFreed = strings.TrimPrefix(part, "docker_freed=")
				}
			}
		}
	}
}
