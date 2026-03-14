// -------------------------------------------------------------------------------
// HTTP Traffic Collector
//
// Author: Alex Freidah
//
// Polls the Cloudflare httpRequestsAdaptiveGroups dataset on a configurable
// interval and updates Prometheus gauges with aggregated traffic statistics.
// Tracks request counts by method/status and byte totals by type. Each poll
// cycle is wrapped in an OpenTelemetry span for trace correlation.
// -------------------------------------------------------------------------------

package collector

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/afreidah/cloudflare-log-collector/internal/cloudflare"
	"github.com/afreidah/cloudflare-log-collector/internal/metrics"
	"github.com/afreidah/cloudflare-log-collector/internal/telemetry"
	"go.opentelemetry.io/otel/attribute"
)

// -------------------------------------------------------------------------
// HTTP COLLECTOR
// -------------------------------------------------------------------------

// HTTPCollector polls Cloudflare for HTTP traffic stats and updates Prometheus
// gauges with the aggregated data.
type HTTPCollector struct {
	cf           *cloudflare.Client
	pollInterval time.Duration
	lastSeen     time.Time
}

// NewHTTPCollector creates an HTTP traffic collector with the given backfill
// window applied to the initial poll.
func NewHTTPCollector(cf *cloudflare.Client, pollInterval time.Duration, backfillWindow time.Duration) *HTTPCollector {
	return &HTTPCollector{
		cf:           cf,
		pollInterval: pollInterval,
		lastSeen:     time.Now().UTC().Add(-backfillWindow),
	}
}

// Run starts the polling loop and blocks until ctx is cancelled. Implements
// the lifecycle.Service interface.
func (c *HTTPCollector) Run(ctx context.Context) error {
	slog.Info("HTTP collector started",
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
			slog.Info("HTTP collector stopped")
			return nil
		case <-ticker.C:
			c.poll(ctx)
		}
	}
}

// poll executes a single HTTP traffic collection cycle within a traced span.
func (c *HTTPCollector) poll(ctx context.Context) {
	ctx, span := telemetry.StartSpan(ctx, "http.poll",
		telemetry.AttrDataset.String("http"),
	)
	defer span.End()

	start := time.Now()
	until := time.Now().UTC()

	groups, err := c.cf.QueryHTTPRequests(ctx, c.lastSeen, until)
	if err != nil {
		slog.ErrorContext(ctx, "HTTP traffic poll failed", "error", err)
		metrics.PollTotal.WithLabelValues("http", "error").Inc()
		metrics.PollDuration.WithLabelValues("http").Observe(time.Since(start).Seconds())
		return
	}

	metrics.PollTotal.WithLabelValues("http", "success").Inc()
	metrics.PollDuration.WithLabelValues("http").Observe(time.Since(start).Seconds())
	metrics.LastPollTimestamp.WithLabelValues("http").Set(float64(time.Now().Unix()))

	span.SetAttributes(attribute.Int("cflog.group_count", len(groups)))

	if len(groups) == 0 {
		slog.DebugContext(ctx, "No new HTTP traffic data")
		c.lastSeen = until
		return
	}

	slog.InfoContext(ctx, "HTTP traffic data fetched", "groups", len(groups))

	// --- Update Prometheus gauges ---
	c.updateMetrics(groups)

	slog.InfoContext(ctx, "HTTP traffic metrics updated")

	c.lastSeen = until
}

// updateMetrics resets and repopulates Prometheus gauges from the latest poll data.
func (c *HTTPCollector) updateMetrics(groups []cloudflare.HTTPRequestGroup) {
	// --- Reset gauges before repopulating ---
	metrics.HTTPRequests.Reset()
	metrics.HTTPBytes.Reset()

	// --- Aggregate totals across all groups ---
	var totalEdgeBytes int64

	for _, g := range groups {
		method := g.Dimensions.ClientRequestHTTPMethodName
		status := fmt.Sprintf("%d", g.Dimensions.EdgeResponseStatus)

		metrics.HTTPRequests.WithLabelValues(method, status).Add(float64(g.Count))

		totalEdgeBytes += g.Sum.EdgeResponseBytes
	}

	metrics.HTTPBytes.WithLabelValues("edge").Set(float64(totalEdgeBytes))
}
