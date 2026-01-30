// -------------------------------------------------------------------------------
// Oracle Watchdog - Metrics
//
// Project: Munchbox / Author: Alex Freidah
//
// Shared Prometheus metrics infrastructure. Provides metric definitions for both
// monitor and agent modes, plus a reusable HTTP metrics server.
// -------------------------------------------------------------------------------

package metrics

import (
	"context"
	"log/slog"
	"net/http"
	"sync"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	monitorOnce sync.Once
	agentOnce   sync.Once
)

// -------------------------------------------------------------------------
// MONITOR METRICS
// -------------------------------------------------------------------------

var (
	MonitorConsulConnected = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_consul_connected",
		Help: "Whether the monitor is connected to Consul (1=connected, 0=disconnected)",
	})

	MonitorSessionActive = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_session_active",
		Help: "Whether the Consul session is active (1=active, 0=inactive)",
	})

	MonitorReconnectAttempts = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "oracle_watchdog_reconnect_attempts_total",
		Help: "Total number of Consul reconnection attempts",
	})

	MonitorSessionRenewals = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "oracle_watchdog_session_renewals_total",
		Help: "Total number of successful session renewals",
	})

	MonitorSessionFailures = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "oracle_watchdog_session_failures_total",
		Help: "Total number of session failures (creation or renewal)",
	})
)

// -------------------------------------------------------------------------
// AGENT METRICS
// -------------------------------------------------------------------------

var (
	AgentConsulConnected = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_agent_consul_connected",
		Help: "Whether the agent is connected to Consul (1=connected, 0=disconnected)",
	})

	AgentOCIConnected = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_agent_oci_connected",
		Help: "Whether the agent is connected to OCI (1=connected, 0=disconnected)",
	})

	AgentNodesMonitored = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_agent_nodes_monitored",
		Help: "Number of nodes being monitored",
	})

	AgentNodesMissing = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "oracle_watchdog_agent_nodes_missing",
		Help: "Number of nodes currently missing",
	})

	AgentRestartAttempts = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "oracle_watchdog_agent_restart_attempts_total",
		Help: "Total restart attempts per node",
	}, []string{"node"})

	AgentRestartSuccesses = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "oracle_watchdog_agent_restart_successes_total",
		Help: "Total successful restarts per node",
	}, []string{"node"})

	AgentRestartFailures = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "oracle_watchdog_agent_restart_failures_total",
		Help: "Total failed restarts per node",
	}, []string{"node"})

	AgentConsulCheckFailures = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "oracle_watchdog_agent_consul_check_failures_total",
		Help: "Total Consul check failures",
	})
)

// -------------------------------------------------------------------------
// REGISTRATION
// -------------------------------------------------------------------------

// RegisterMonitor registers all monitor-mode metrics. Safe to call multiple times.
func RegisterMonitor() {
	monitorOnce.Do(func() {
		prometheus.MustRegister(
			MonitorConsulConnected,
			MonitorSessionActive,
			MonitorReconnectAttempts,
			MonitorSessionRenewals,
			MonitorSessionFailures,
		)
	})
}

// RegisterAgent registers all agent-mode metrics. Safe to call multiple times.
func RegisterAgent() {
	agentOnce.Do(func() {
		prometheus.MustRegister(
			AgentConsulConnected,
			AgentOCIConnected,
			AgentNodesMonitored,
			AgentNodesMissing,
			AgentRestartAttempts,
			AgentRestartSuccesses,
			AgentRestartFailures,
			AgentConsulCheckFailures,
		)
	})
}

// -------------------------------------------------------------------------
// SERVER
// -------------------------------------------------------------------------

// Serve starts a Prometheus metrics HTTP server on the given port. Blocks until
// context is cancelled. Port should include colon (e.g. ":9102").
func Serve(ctx context.Context, port string) {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	server := &http.Server{
		Addr:    port,
		Handler: mux,
	}

	go func() {
		<-ctx.Done()
		_ = server.Close()
	}()

	slog.Info("metrics server starting", "port", port)
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		slog.Warn("metrics server error", "error", err)
	}
}
