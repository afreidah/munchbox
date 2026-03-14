// -------------------------------------------------------------------------------
// Firewall Event Collector
//
// Author: Alex Freidah
//
// Polls the Cloudflare firewallEventsAdaptive dataset on a configurable interval
// and ships events to Loki as structured JSON log lines. Tracks the last-seen
// event timestamp for seek-based pagination to avoid duplicates across polls.
// Each poll cycle is wrapped in an OpenTelemetry span for trace correlation.
// -------------------------------------------------------------------------------

package collector

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"

	"github.com/afreidah/cloudflare-log-collector/internal/cloudflare"
	"github.com/afreidah/cloudflare-log-collector/internal/loki"
	"github.com/afreidah/cloudflare-log-collector/internal/metrics"
	"github.com/afreidah/cloudflare-log-collector/internal/telemetry"
	"go.opentelemetry.io/otel/attribute"
)

// -------------------------------------------------------------------------
// FIREWALL COLLECTOR
// -------------------------------------------------------------------------

// FirewallCollector polls Cloudflare for firewall events and ships them to Loki.
type FirewallCollector struct {
	cf           *cloudflare.Client
	loki         *loki.Client
	pollInterval time.Duration
	lastSeen     time.Time
	batchSize    int
}

// NewFirewallCollector creates a firewall event collector with the given backfill
// window applied to the initial poll.
func NewFirewallCollector(cf *cloudflare.Client, lokiClient *loki.Client, pollInterval time.Duration, backfillWindow time.Duration, batchSize int) *FirewallCollector {
	return &FirewallCollector{
		cf:           cf,
		loki:         lokiClient,
		pollInterval: pollInterval,
		lastSeen:     time.Now().UTC().Add(-backfillWindow),
		batchSize:    batchSize,
	}
}

// Run starts the polling loop and blocks until ctx is cancelled. Implements
// the lifecycle.Service interface.
func (c *FirewallCollector) Run(ctx context.Context) error {
	slog.Info("Firewall collector started",
		"poll_interval", c.pollInterval,
		"backfill_from", c.lastSeen.Format(time.RFC3339),
	)

	// --- Initial poll on startup ---
	c.poll(ctx)

	ticker := time.NewTicker(c.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("Firewall collector stopped")
			return nil
		case <-ticker.C:
			c.poll(ctx)
		}
	}
}

// poll executes a single firewall event collection cycle within a traced span.
func (c *FirewallCollector) poll(ctx context.Context) {
	ctx, span := telemetry.StartSpan(ctx, "firewall.poll",
		telemetry.AttrDataset.String("firewall"),
	)
	defer span.End()

	start := time.Now()
	until := time.Now().UTC()

	events, err := c.cf.QueryFirewallEvents(ctx, c.lastSeen, until)
	if err != nil {
		slog.ErrorContext(ctx, "Firewall poll failed", "error", err)
		metrics.PollTotal.WithLabelValues("firewall", "error").Inc()
		metrics.PollDuration.WithLabelValues("firewall").Observe(time.Since(start).Seconds())
		return
	}

	metrics.PollTotal.WithLabelValues("firewall", "success").Inc()
	metrics.PollDuration.WithLabelValues("firewall").Observe(time.Since(start).Seconds())
	metrics.LastPollTimestamp.WithLabelValues("firewall").Set(float64(time.Now().Unix()))

	span.SetAttributes(attribute.Int("cflog.event_count", len(events)))

	if len(events) == 0 {
		slog.DebugContext(ctx, "No new firewall events")
		return
	}

	slog.InfoContext(ctx, "Firewall events fetched", "count", len(events))

	// --- Ship events to Loki in batches ---
	if err := c.shipToLoki(ctx, events); err != nil {
		slog.ErrorContext(ctx, "Failed to ship firewall events to Loki", "error", err)
		return
	}

	slog.InfoContext(ctx, "Firewall events pushed to Loki", "count", len(events))

	// --- Update metrics and cursor ---
	for _, e := range events {
		metrics.FirewallEventsTotal.WithLabelValues(e.Action).Inc()
	}

	// --- Advance cursor to the last event's timestamp ---
	lastEvent := events[len(events)-1]
	if t, err := time.Parse(time.RFC3339Nano, lastEvent.Datetime); err == nil {
		c.lastSeen = t
	}
}

// shipToLoki sends firewall events to Loki as JSON log lines in batches.
func (c *FirewallCollector) shipToLoki(ctx context.Context, events []cloudflare.FirewallEvent) error {
	labels := map[string]string{
		"job":  "cloudflare",
		"type": "firewall",
		"zone": "munchbox.cc",
	}

	entries := make([]loki.Entry, 0, len(events))
	for _, e := range events {
		line, err := json.Marshal(e)
		if err != nil {
			slog.WarnContext(ctx, "Failed to marshal firewall event", "error", err)
			continue
		}

		t, err := time.Parse(time.RFC3339Nano, e.Datetime)
		if err != nil {
			t = time.Now().UTC()
		}

		entries = append(entries, loki.NewEntry(t, string(line)))
	}

	// --- Send in batches ---
	for i := 0; i < len(entries); i += c.batchSize {
		end := i + c.batchSize
		if end > len(entries) {
			end = len(entries)
		}

		if err := c.loki.Push(ctx, labels, entries[i:end]); err != nil {
			return err
		}
	}

	return nil
}
