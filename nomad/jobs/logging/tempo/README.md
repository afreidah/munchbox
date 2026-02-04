# Tempo

Distributed tracing backend receiving traces via OpenTelemetry (OTLP),
Zipkin, and Jaeger protocols. Traefik, Grafana, Alertmanager, Promtail, and
the Docker Registry all send traces here. Generates RED metrics from traces
and remote-writes them to Prometheus. Queryable through Grafana using TraceQL.
Co-located with Loki on the same node for the observability stack.

## Dependencies

- **Prometheus** -- receives trace-derived RED metrics via remote write
- **Grafana** -- primary query and visualization interface
