// -------------------------------------------------------------------------------
// Oracle Watchdog - Main Entry Point
//
// Project: Munchbox / Author: Alex Freidah
//
// Monitors Oracle Cloud free-tier nodes and restarts them when unresponsive.
// Oracle periodically reclaims free-tier instances, which can leave them in a
// stuck state requiring a full stop/start cycle to recover.
//
// Modes:
//   - monitor: Runs on Oracle nodes, maintains Consul session heartbeat
//   - agent: Runs on homelab, watches sessions and triggers OCI stop/start
// -------------------------------------------------------------------------------

package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/afreidah/oracle-watchdog/internal/agent"
	"github.com/afreidah/oracle-watchdog/internal/config"
	"github.com/afreidah/oracle-watchdog/internal/monitor"
	"github.com/afreidah/oracle-watchdog/internal/tracing"
)

func main() {
	mode := flag.String("mode", "", "Run mode: 'monitor' or 'agent'")
	configPath := flag.String("config", "/etc/oracle-watchdog/config.yaml", "Path to config file (agent mode)")
	nodeName := flag.String("node", "", "Node name for heartbeat (monitor mode, defaults to hostname)")
	enableTracing := flag.Bool("tracing", false, "Enable OpenTelemetry tracing")
	dryRun := flag.Bool("dry-run", false, "Log restart actions without executing them (agent mode)")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// --- Initialize tracing if enabled ---
	if *enableTracing {
		shutdown, err := tracing.Init(ctx, *mode)
		if err != nil {
			slog.Warn("failed to initialize tracing, continuing without", "error", err)
		} else {
			defer func() {
				if err := shutdown(ctx); err != nil {
					slog.Warn("tracing shutdown error", "error", err)
				}
			}()
		}
	}

	// --- Graceful shutdown on SIGINT/SIGTERM ---
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		slog.Info("shutdown signal received")
		cancel()
	}()

	switch *mode {
	case "monitor":
		runMonitor(ctx, *nodeName)
	case "agent":
		runAgent(ctx, *configPath, *dryRun)
	default:
		slog.Error("invalid mode", "mode", *mode, "valid", []string{"monitor", "agent"})
		flag.Usage()
		os.Exit(1)
	}
}

// -------------------------------------------------------------------------
// MODE RUNNERS
// -------------------------------------------------------------------------

func runMonitor(ctx context.Context, nodeName string) {
	if nodeName == "" {
		var err error
		nodeName, err = os.Hostname()
		if err != nil {
			slog.Error("failed to get hostname", "error", err)
			os.Exit(1)
		}
	}

	slog.Info("starting monitor mode", "node", nodeName)

	m, err := monitor.New(nodeName)
	if err != nil {
		slog.Error("failed to create monitor", "error", err)
		os.Exit(1)
	}

	if err := m.Run(ctx); err != nil {
		slog.Error("monitor error", "error", err)
		os.Exit(1)
	}
}

func runAgent(ctx context.Context, configPath string, dryRun bool) {
	cfg, err := config.Load(configPath)
	if err != nil {
		slog.Error("failed to load config", "path", configPath, "error", err)
		os.Exit(1)
	}

	cfg.DryRun = dryRun

	slog.Info("starting agent mode", "nodes", len(cfg.Nodes), "timeout", cfg.Timeout, "dry_run", dryRun)

	a, err := agent.New(cfg)
	if err != nil {
		slog.Error("failed to create agent", "error", err)
		os.Exit(1)
	}

	if err := a.Run(ctx); err != nil {
		slog.Error("agent error", "error", err)
		os.Exit(1)
	}
}
