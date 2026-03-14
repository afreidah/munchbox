// -------------------------------------------------------------------------------
// Loki Push Client
//
// Author: Alex Freidah
//
// HTTP client for the Loki push API (POST /loki/api/v1/push). Batches log
// entries and sends them as JSON streams with configurable labels and tenant ID.
// Used to ship Cloudflare firewall events into the cluster's Loki instance.
// -------------------------------------------------------------------------------

package loki

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/afreidah/cloudflare-log-collector/internal/metrics"
	"github.com/afreidah/cloudflare-log-collector/internal/telemetry"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// -------------------------------------------------------------------------
// CLIENT
// -------------------------------------------------------------------------

// Client pushes log entries to the Loki HTTP API.
type Client struct {
	endpoint   string
	tenantID   string
	httpClient *http.Client
}

// NewClient creates a Loki push API client.
func NewClient(endpoint, tenantID string) *Client {
	return &Client{
		endpoint: endpoint,
		tenantID: tenantID,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// -------------------------------------------------------------------------
// PUSH API TYPES
// -------------------------------------------------------------------------

// pushRequest is the JSON payload for POST /loki/api/v1/push.
type pushRequest struct {
	Streams []stream `json:"streams"`
}

// stream represents a single log stream with labels and entries.
type stream struct {
	Stream map[string]string `json:"stream"`
	Values [][]string        `json:"values"`
}

// -------------------------------------------------------------------------
// PUSH
// -------------------------------------------------------------------------

// Push sends a batch of log entries to Loki under the given stream labels.
// Each entry is a [timestamp_nanos, json_line] pair.
func (c *Client) Push(ctx context.Context, labels map[string]string, entries []Entry) error {
	if len(entries) == 0 {
		return nil
	}

	ctx, span := telemetry.StartSpan(ctx, "loki.push",
		attribute.Int("loki.entry_count", len(entries)),
	)
	defer span.End()

	start := time.Now()

	values := make([][]string, len(entries))
	for i, e := range entries {
		values[i] = []string{e.Timestamp, e.Line}
	}

	req := pushRequest{
		Streams: []stream{
			{
				Stream: labels,
				Values: values,
			},
		},
	}

	payload, err := json.Marshal(req)
	if err != nil {
		metrics.LokiPushTotal.WithLabelValues("error").Inc()
		return fmt.Errorf("marshal push request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.endpoint+"/loki/api/v1/push", bytes.NewReader(payload))
	if err != nil {
		metrics.LokiPushTotal.WithLabelValues("error").Inc()
		return fmt.Errorf("create push request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-Scope-OrgID", c.tenantID)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		metrics.LokiPushTotal.WithLabelValues("error").Inc()
		return fmt.Errorf("push request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	metrics.LokiPushDuration.Observe(time.Since(start).Seconds())

	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		metrics.LokiPushTotal.WithLabelValues("error").Inc()
		err := fmt.Errorf("loki push HTTP %d: %s", resp.StatusCode, string(body))
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}

	metrics.LokiPushTotal.WithLabelValues("success").Inc()
	return nil
}

// -------------------------------------------------------------------------
// ENTRY
// -------------------------------------------------------------------------

// Entry is a single log line with a nanosecond-precision timestamp string.
type Entry struct {
	Timestamp string // nanoseconds since epoch as a string
	Line      string // JSON-encoded log line
}

// NewEntry creates a log entry from a time and JSON line.
func NewEntry(t time.Time, line string) Entry {
	return Entry{
		Timestamp: fmt.Sprintf("%d", t.UnixNano()),
		Line:      line,
	}
}
