// -------------------------------------------------------------------------------
// Trace Handler Tests
//
// Author: Alex Freidah
//
// Tests for the slog TraceHandler that injects trace_id and span_id from
// OpenTelemetry span context into log records. Verifies injection with active
// spans and no-op behavior without spans.
// -------------------------------------------------------------------------------

package telemetry

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"testing"

	"go.opentelemetry.io/otel/trace"
)

// -------------------------------------------------------------------------
// TRACE INJECTION
// -------------------------------------------------------------------------

func TestTraceHandler_InjectsTraceID(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, nil)
	handler := NewTraceHandler(inner)
	logger := slog.New(handler)

	// --- Create a fake span context ---
	traceID, _ := trace.TraceIDFromHex("0102030405060708090a0b0c0d0e0f10")
	spanID, _ := trace.SpanIDFromHex("0102030405060708")
	sc := trace.NewSpanContext(trace.SpanContextConfig{
		TraceID:    traceID,
		SpanID:     spanID,
		TraceFlags: trace.FlagsSampled,
	})
	ctx := trace.ContextWithSpanContext(context.Background(), sc)

	logger.InfoContext(ctx, "test message")

	var record map[string]any
	if err := json.Unmarshal(buf.Bytes(), &record); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	if record["trace_id"] != "0102030405060708090a0b0c0d0e0f10" {
		t.Errorf("trace_id = %q, want %q", record["trace_id"], "0102030405060708090a0b0c0d0e0f10")
	}
	if record["span_id"] != "0102030405060708" {
		t.Errorf("span_id = %q, want %q", record["span_id"], "0102030405060708")
	}
}

func TestTraceHandler_NoSpanContext(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, nil)
	handler := NewTraceHandler(inner)
	logger := slog.New(handler)

	logger.Info("no span")

	var record map[string]any
	if err := json.Unmarshal(buf.Bytes(), &record); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	if _, ok := record["trace_id"]; ok {
		t.Error("trace_id should not be present without an active span")
	}
	if _, ok := record["span_id"]; ok {
		t.Error("span_id should not be present without an active span")
	}
}

// -------------------------------------------------------------------------
// DELEGATION
// -------------------------------------------------------------------------

func TestTraceHandler_WithAttrs(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, nil)
	handler := NewTraceHandler(inner)

	attrHandler := handler.WithAttrs([]slog.Attr{slog.String("service", "test")})
	logger := slog.New(attrHandler)

	logger.Info("with attrs")

	var record map[string]any
	if err := json.Unmarshal(buf.Bytes(), &record); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	if record["service"] != "test" {
		t.Errorf("service = %q, want %q", record["service"], "test")
	}
}

func TestTraceHandler_WithGroup(t *testing.T) {
	var buf bytes.Buffer
	inner := slog.NewJSONHandler(&buf, nil)
	handler := NewTraceHandler(inner)

	groupHandler := handler.WithGroup("grp")
	logger := slog.New(groupHandler)

	logger.Info("with group", "key", "val")

	var record map[string]any
	if err := json.Unmarshal(buf.Bytes(), &record); err != nil {
		t.Fatalf("unmarshal log: %v", err)
	}

	grp, ok := record["grp"].(map[string]any)
	if !ok {
		t.Fatal("expected group 'grp' in log output")
	}
	if grp["key"] != "val" {
		t.Errorf("grp.key = %q, want %q", grp["key"], "val")
	}
}
