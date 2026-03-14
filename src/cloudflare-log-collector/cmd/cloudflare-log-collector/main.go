// -------------------------------------------------------------------------------
// Cloudflare Log Collector - Entry Point
//
// Author: Alex Freidah
//
// Polls the Cloudflare GraphQL Analytics API for firewall events and HTTP
// traffic statistics. Ships firewall events to Loki as structured JSON logs
// and exposes HTTP traffic metrics via Prometheus. Traces every poll cycle
// with OpenTelemetry for Tempo correlation.
// -------------------------------------------------------------------------------

package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/afreidah/cloudflare-log-collector/internal/cloudflare"
	"github.com/afreidah/cloudflare-log-collector/internal/collector"
	"github.com/afreidah/cloudflare-log-collector/internal/config"
	"github.com/afreidah/cloudflare-log-collector/internal/lifecycle"
	"github.com/afreidah/cloudflare-log-collector/internal/loki"
	"github.com/afreidah/cloudflare-log-collector/internal/metrics"
	"github.com/afreidah/cloudflare-log-collector/internal/telemetry"
)

// main is the process entry point. Loads config, initializes tracing and
// logging, starts background collectors, and runs the metrics HTTP server.
func main() {
	if len(os.Args) > 1 && os.Args[1] == "version" {
		fmt.Printf("cloudflare-log-collector %s (%s)\n", telemetry.Version, runtime.Version())
		return
	}

	configPath := flag.String("config", "config.yaml", "Path to configuration file")
	flag.Parse()

	// --- Load configuration ---
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
		os.Exit(1)
	}

	// --- Initialize structured logger with trace correlation ---
	var logLevel slog.LevelVar
	logLevel.Set(config.ParseLogLevel(cfg.Logging.Level))
	jsonHandler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: &logLevel})
	traceHandler := telemetry.NewTraceHandler(jsonHandler)
	slog.SetDefault(slog.New(traceHandler))

	// --- Initialize tracing ---
	ctx := context.Background()
	shutdownTracer, err := telemetry.InitTracer(ctx, cfg.Tracing)
	if err != nil {
		slog.Error("Failed to initialize tracer", "error", err)
		os.Exit(1)
	}

	// --- Set build info metric ---
	metrics.BuildInfo.WithLabelValues(telemetry.Version, runtime.Version()).Set(1)

	// --- Create Cloudflare client ---
	cfClient := cloudflare.NewClient(cfg.Cloudflare.APIToken, cfg.Cloudflare.ZoneID)

	// --- Create Loki client ---
	lokiClient := loki.NewClient(cfg.Loki.Endpoint, cfg.Loki.TenantID)

	// --- Start background collectors with lifecycle manager ---
	sm := lifecycle.NewManager()

	firewallCollector := collector.NewFirewallCollector(
		cfClient, lokiClient,
		cfg.Cloudflare.PollInterval,
		cfg.Cloudflare.BackfillWindow,
		cfg.Loki.BatchSize,
	)
	sm.Register("firewall-collector", firewallCollector)

	httpCollector := collector.NewHTTPCollector(
		cfClient,
		cfg.Cloudflare.PollInterval,
		cfg.Cloudflare.BackfillWindow,
	)
	sm.Register("http-collector", httpCollector)

	bgCtx, bgCancel := context.WithCancel(context.Background())
	defer bgCancel()
	bgDone := make(chan struct{})
	go func() {
		sm.Run(bgCtx)
		close(bgDone)
	}()

	// --- Setup HTTP server for metrics and health ---
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	// healthHandler returns a simple health check response.
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = fmt.Fprint(w, `{"status":"ok"}`)
	})

	httpServer := &http.Server{
		Addr:              cfg.Metrics.Listen,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	// --- Log startup info ---
	slog.Info("Cloudflare Log Collector starting",
		"version", telemetry.Version,
		"listen", cfg.Metrics.Listen,
		"poll_interval", cfg.Cloudflare.PollInterval,
		"backfill_window", cfg.Cloudflare.BackfillWindow,
		"loki_endpoint", cfg.Loki.Endpoint,
	)

	if cfg.Tracing.Enabled {
		slog.Info("Tracing enabled",
			"endpoint", cfg.Tracing.Endpoint,
			"sample_rate", cfg.Tracing.SampleRate,
			"insecure", cfg.Tracing.Insecure,
		)
	}

	// --- Handle graceful shutdown ---
	shutdownDone := make(chan struct{})
	go func() {
		defer close(shutdownDone)

		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		sig := <-sigChan

		slog.Info("Shutting down", "signal", sig.String())

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		// --- Drain HTTP server ---
		if err := httpServer.Shutdown(shutdownCtx); err != nil {
			slog.Error("HTTP server shutdown error", "error", err)
		}

		// --- Stop background collectors ---
		bgCancel()
		<-bgDone
		sm.Stop(10 * time.Second)

		// --- Flush traces ---
		traceCtx, traceCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer traceCancel()
		if err := shutdownTracer(traceCtx); err != nil {
			slog.Error("Tracer shutdown error", "error", err)
		}
	}()

	// --- Start metrics server ---
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("Server error", "error", err)
		os.Exit(1)
	}

	<-shutdownDone
	slog.Info("Server stopped")
}
