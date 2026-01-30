// -------------------------------------------------------------------------------
// Oracle Watchdog - Tracing
//
// Project: Munchbox / Author: Alex Freidah
//
// OpenTelemetry tracing infrastructure for shipping traces to Tempo. Provides
// initialization and span helpers for the restart cycle and node monitoring.
// -------------------------------------------------------------------------------

package tracing

import (
	"context"
	"log/slog"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
	"go.opentelemetry.io/otel/trace"
)

const (
	serviceName    = "oracle-watchdog"
	tracerName     = "github.com/afreidah/oracle-watchdog"
	defaultOTLPURL = "http://tempo.service.consul:4318"
)

var tracer trace.Tracer

// Init initializes the OpenTelemetry tracer with OTLP HTTP exporter.
// Uses OTEL_EXPORTER_OTLP_ENDPOINT env var or defaults to Tempo service.
// Returns a shutdown function that should be deferred.
func Init(ctx context.Context, mode string) (func(context.Context) error, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = defaultOTLPURL
	}

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion("1.0.0"),
			attribute.String("mode", mode),
		),
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	tracer = tp.Tracer(tracerName)

	slog.Info("tracing initialized", "endpoint", endpoint, "mode", mode)

	return tp.Shutdown, nil
}

// Tracer returns the global tracer instance.
func Tracer() trace.Tracer {
	if tracer == nil {
		return otel.Tracer(tracerName)
	}
	return tracer
}

// -------------------------------------------------------------------------
// SPAN HELPERS
// -------------------------------------------------------------------------

// StartSpan starts a new span with the given name and returns context + span.
func StartSpan(ctx context.Context, name string, attrs ...attribute.KeyValue) (context.Context, trace.Span) {
	return Tracer().Start(ctx, name, trace.WithAttributes(attrs...))
}

// NodeAttr creates a node name attribute.
func NodeAttr(name string) attribute.KeyValue {
	return attribute.String("node.name", name)
}

// InstanceAttr creates an instance ID attribute.
func InstanceAttr(id string) attribute.KeyValue {
	return attribute.String("oci.instance_id", id)
}

// StateAttr creates a lifecycle state attribute.
func StateAttr(state string) attribute.KeyValue {
	return attribute.String("oci.lifecycle_state", state)
}

// StatusAttr creates a status attribute (alive, missing, restarting).
func StatusAttr(status string) attribute.KeyValue {
	return attribute.String("node.status", status)
}

// ErrorAttr creates an error attribute.
func ErrorAttr(err error) attribute.KeyValue {
	return attribute.String("error", err.Error())
}

// DurationAttr creates a duration attribute in seconds.
func DurationAttr(name string, seconds float64) attribute.KeyValue {
	return attribute.Float64(name, seconds)
}
