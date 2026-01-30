// -------------------------------------------------------------------------------
// Oracle Watchdog - Agent Mode
//
// Project: Munchbox / Author: Alex Freidah
//
// Runs on homelab infrastructure and monitors Consul for missing Oracle node
// sessions. When a node's session has been absent longer than the configured
// timeout, triggers an OCI stop/start cycle to recover the instance.
//
// Self-healing design: never crashes due to Consul or OCI unavailability.
// Continuously attempts reconnection and emits metrics on current state.
// -------------------------------------------------------------------------------

package agent

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	consul "github.com/hashicorp/consul/api"
	"go.opentelemetry.io/otel/codes"

	"github.com/afreidah/oracle-watchdog/internal/config"
	"github.com/afreidah/oracle-watchdog/internal/metrics"
	"github.com/afreidah/oracle-watchdog/internal/oci"
	"github.com/afreidah/oracle-watchdog/internal/tracing"
)

const (
	sessionKeyPath         = "oracle-watchdog/nodes"
	metricsPort            = ":9105"
	maxConsecutiveFailures = 3
)

// -------------------------------------------------------------------------
// AGENT STATE
// -------------------------------------------------------------------------

type connectionState int

const (
	stateDisconnected connectionState = iota
	stateConnected
)

func (s connectionState) String() string {
	switch s {
	case stateDisconnected:
		return "disconnected"
	case stateConnected:
		return "connected"
	default:
		return "unknown"
	}
}

// -------------------------------------------------------------------------
// AGENT
// -------------------------------------------------------------------------

// Agent monitors Oracle nodes and restarts unresponsive instances.
type Agent struct {
	cfg *config.Config

	mu          sync.RWMutex
	consul      *consul.Client
	oci         *oci.Client
	consulState connectionState
	ociState    connectionState

	// Tracks when each node was first seen as missing
	missingSince map[string]time.Time

	// Tracks nodes currently being restarted (prevent duplicate restarts)
	restarting map[string]bool

	// Tracks consecutive restart attempts per node (resets on recovery)
	restartAttempts map[string]int

	// Consecutive failure tracking for connection health
	consulFailures int
	ociFailures    int
}

// New creates an Agent with the given configuration. Always succeeds -
// connections to Consul and OCI happen asynchronously in Run().
func New(cfg *config.Config) (*Agent, error) {
	metrics.AgentNodesMonitored.Set(float64(len(cfg.Nodes)))

	return &Agent{
		cfg:             cfg,
		consulState:     stateDisconnected,
		ociState:        stateDisconnected,
		missingSince:    make(map[string]time.Time),
		restarting:      make(map[string]bool),
		restartAttempts: make(map[string]int),
	}, nil
}

// Run starts the monitoring loop. Never returns an error due to connection
// issues - continuously retries and emits metrics. Only returns on context
// cancellation.
func (a *Agent) Run(ctx context.Context) error {
	metrics.RegisterAgent()
	go metrics.Serve(ctx, metricsPort)

	ticker := time.NewTicker(a.cfg.CheckInterval)
	defer ticker.Stop()

	// --- Initial connection attempts ---
	a.tryConnectConsul()
	a.tryConnectOCI()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			a.tick(ctx)
		}
	}
}

func (a *Agent) tick(ctx context.Context) {
	a.mu.RLock()
	consulState := a.consulState
	ociState := a.ociState
	a.mu.RUnlock()

	// --- Ensure connections ---
	if consulState == stateDisconnected {
		a.tryConnectConsul()
	}
	if ociState == stateDisconnected {
		a.tryConnectOCI()
	}

	// --- Check nodes if Consul is connected ---
	a.mu.RLock()
	consulState = a.consulState
	a.mu.RUnlock()

	if consulState == stateConnected {
		a.checkNodes(ctx)
	}
}

// -------------------------------------------------------------------------
// CONNECTION MANAGEMENT
// -------------------------------------------------------------------------

func (a *Agent) tryConnectConsul() {
	cfg := consul.DefaultConfig()
	cfg.Address = a.cfg.ConsulAddress

	client, err := consul.NewClient(cfg)
	if err != nil {
		slog.Warn("failed to create consul client", "error", err)
		return
	}

	// --- Verify connectivity ---
	_, err = client.Status().Leader()
	if err != nil {
		slog.Warn("consul not reachable", "error", err, "address", a.cfg.ConsulAddress)
		return
	}

	a.mu.Lock()
	a.consul = client
	a.consulState = stateConnected
	a.consulFailures = 0
	a.mu.Unlock()

	metrics.AgentConsulConnected.Set(1)
	slog.Info("connected to consul", "address", a.cfg.ConsulAddress)
}

func (a *Agent) tryConnectOCI() {
	client, err := oci.NewClient(a.cfg.OCI.ConfigPath, a.cfg.OCI.Profile)
	if err != nil {
		slog.Warn("failed to create oci client", "error", err)
		return
	}

	a.mu.Lock()
	a.oci = client
	a.ociState = stateConnected
	a.ociFailures = 0
	a.mu.Unlock()

	metrics.AgentOCIConnected.Set(1)
	slog.Info("connected to oci", "profile", a.cfg.OCI.Profile)
}

func (a *Agent) markConsulDisconnected() {
	a.mu.Lock()
	a.consul = nil
	a.consulState = stateDisconnected
	a.mu.Unlock()

	metrics.AgentConsulConnected.Set(0)
	slog.Warn("consul connection lost")
}

func (a *Agent) markOCIDisconnected() {
	a.mu.Lock()
	a.oci = nil
	a.ociState = stateDisconnected
	a.mu.Unlock()

	metrics.AgentOCIConnected.Set(0)
	slog.Warn("oci connection lost")
}

// -------------------------------------------------------------------------
// NODE MONITORING
// -------------------------------------------------------------------------

func (a *Agent) checkNodes(ctx context.Context) {
	ctx, span := tracing.StartSpan(ctx, "agent.check_nodes")
	defer span.End()

	a.mu.RLock()
	client := a.consul
	a.mu.RUnlock()

	if client == nil {
		span.SetStatus(codes.Error, "consul client nil")
		return
	}

	kv := client.KV()
	now := time.Now()
	missingCount := 0
	hadError := false

	for _, node := range a.cfg.Nodes {
		key := fmt.Sprintf("%s/%s", sessionKeyPath, node.Name)

		pair, _, err := kv.Get(key, nil)
		if err != nil {
			slog.Warn("failed to check node key", "node", node.Name, "error", err)
			metrics.AgentConsulCheckFailures.Inc()
			hadError = true
			span.RecordError(err)

			// --- Check for obvious connection errors ---
			if isConnectionError(err) {
				a.markConsulDisconnected()
				span.SetStatus(codes.Error, "consul connection lost")
				return
			}
			continue
		}

		a.mu.Lock()

		if pair == nil {
			// --- Node key missing (session expired) ---
			missingCount++

			if _, isRestarting := a.restarting[node.Name]; isRestarting {
				// Already restarting, skip
				a.mu.Unlock()
				continue
			}

			// Check if max restart attempts exceeded
			if a.cfg.MaxRestartAttempts > 0 && a.restartAttempts[node.Name] >= a.cfg.MaxRestartAttempts {
				// Already at max attempts, don't restart again
				a.mu.Unlock()
				continue
			}

			if firstMissing, exists := a.missingSince[node.Name]; exists {
				missingDuration := now.Sub(firstMissing)

				if missingDuration >= a.cfg.Timeout {
					// Check again under lock for max attempts
					if a.cfg.MaxRestartAttempts > 0 && a.restartAttempts[node.Name] >= a.cfg.MaxRestartAttempts {
						slog.Error("node exceeded max restart attempts, giving up",
							"node", node.Name,
							"attempts", a.restartAttempts[node.Name],
							"max_attempts", a.cfg.MaxRestartAttempts,
						)
						a.mu.Unlock()
						continue
					}

					slog.Warn("node exceeded timeout, triggering restart",
						"node", node.Name,
						"missing_for", missingDuration,
						"timeout", a.cfg.Timeout,
						"attempt", a.restartAttempts[node.Name]+1,
					)

					// Mark as restarting and clear tracking
					a.restarting[node.Name] = true
					delete(a.missingSince, node.Name)
					a.mu.Unlock()

					// Restart in goroutine to not block other node checks
					go a.restartNode(ctx, node)
					continue
				}

				slog.Info("node missing",
					"node", node.Name,
					"missing_for", missingDuration,
					"timeout_in", a.cfg.Timeout-missingDuration,
				)
			} else {
				slog.Info("node went missing", "node", node.Name)
				a.missingSince[node.Name] = now
			}
		} else {
			// --- Node is alive ---
			if _, wasMissing := a.missingSince[node.Name]; wasMissing {
				slog.Info("node recovered", "node", node.Name)
				delete(a.missingSince, node.Name)
			}
			// Reset restart attempts on recovery
			if a.restartAttempts[node.Name] > 0 {
				slog.Info("resetting restart attempts", "node", node.Name, "previous_attempts", a.restartAttempts[node.Name])
				delete(a.restartAttempts, node.Name)
			}
		}

		a.mu.Unlock()
	}

	metrics.AgentNodesMissing.Set(float64(missingCount))

	// --- Track consecutive failures for connection health ---
	a.mu.Lock()
	if hadError {
		a.consulFailures++
		if a.consulFailures >= maxConsecutiveFailures {
			slog.Warn("consul consecutive failures exceeded threshold",
				"failures", a.consulFailures,
				"threshold", maxConsecutiveFailures,
			)
			a.mu.Unlock()
			a.markConsulDisconnected()
			span.SetStatus(codes.Error, "consecutive failures exceeded")
			return
		}
	} else {
		a.consulFailures = 0
	}
	a.mu.Unlock()

	span.SetAttributes(
		tracing.DurationAttr("nodes_missing", float64(missingCount)),
		tracing.DurationAttr("nodes_total", float64(len(a.cfg.Nodes))),
	)
	span.SetStatus(codes.Ok, "check complete")
}

func (a *Agent) restartNode(ctx context.Context, node config.NodeConfig) {
	ctx, span := tracing.StartSpan(ctx, "agent.restart_node",
		tracing.NodeAttr(node.Name),
		tracing.InstanceAttr(node.InstanceID),
	)
	defer span.End()

	defer func() {
		a.mu.Lock()
		delete(a.restarting, node.Name)
		a.mu.Unlock()
	}()

	a.mu.RLock()
	ociClient := a.oci
	ociState := a.ociState
	a.mu.RUnlock()

	if ociState == stateDisconnected || ociClient == nil {
		slog.Warn("cannot restart node, oci disconnected", "node", node.Name)
		metrics.AgentRestartFailures.WithLabelValues(node.Name).Inc()
		span.SetStatus(codes.Error, "oci disconnected")
		return
	}

	metrics.AgentRestartAttempts.WithLabelValues(node.Name).Inc()

	// --- Dry-run mode: log but don't execute ---
	if a.cfg.DryRun {
		slog.Info("[DRY-RUN] would initiate OCI restart",
			"node", node.Name,
			"instance_id", node.InstanceID,
			"compartment_id", node.CompartmentID,
		)
		metrics.AgentRestartSuccesses.WithLabelValues(node.Name).Inc()
		span.SetStatus(codes.Ok, "dry-run restart simulated")
		return
	}

	// Increment restart attempts counter
	a.mu.Lock()
	a.restartAttempts[node.Name]++
	attempt := a.restartAttempts[node.Name]
	a.mu.Unlock()

	slog.Info("initiating OCI restart", "node", node.Name, "instance_id", node.InstanceID, "attempt", attempt)

	if err := ociClient.RestartInstance(ctx, node.InstanceID, node.CompartmentID); err != nil {
		slog.Error("restart failed", "node", node.Name, "error", err)
		metrics.AgentRestartFailures.WithLabelValues(node.Name).Inc()
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())

		// --- Track OCI failures ---
		a.mu.Lock()
		a.ociFailures++
		shouldDisconnect := a.ociFailures >= maxConsecutiveFailures || isConnectionError(err)
		a.mu.Unlock()

		if shouldDisconnect {
			slog.Warn("oci failures exceeded threshold or connection error detected",
				"failures", a.ociFailures,
			)
			a.markOCIDisconnected()
		}
		return
	}

	// --- Success - reset failure counter ---
	a.mu.Lock()
	a.ociFailures = 0
	a.mu.Unlock()

	metrics.AgentRestartSuccesses.WithLabelValues(node.Name).Inc()
	slog.Info("restart completed", "node", node.Name)
	span.SetStatus(codes.Ok, "restart completed")
}

// -------------------------------------------------------------------------
// UTILITIES
// -------------------------------------------------------------------------

// connectionErrorPatterns are substrings that indicate a connection-level failure.
var connectionErrorPatterns = []string{
	"connection refused",
	"connection reset",
	"no such host",
	"timeout",
	"deadline exceeded",
	"EOF",
	"network unreachable",
	"no route to host",
	"broken pipe",
	"connection timed out",
	"i/o timeout",
	"dial tcp",
	"dial udp",
}

func isConnectionError(err error) bool {
	if err == nil {
		return false
	}
	errStr := strings.ToLower(err.Error())
	for _, pattern := range connectionErrorPatterns {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}
	return false
}
