# tempo

Distributed tracing backend. Accepts traces via OTLP (gRPC + HTTP), Zipkin,
and Jaeger (HTTP + gRPC). Traefik, Grafana, Alertmanager, CoreDNS, the
Docker Registry, and others ship traces here. Generates RED metrics from
traces and remote-writes them to Prometheus.

## Image

`grafana/tempo:3.0.0` (plus `busybox:1.38.0` for init-storage)

## Hostname / exposure

- `tempo.munchbox` (internal-only hostname, no public `.cc`)
- HTTPS router gated by `dashboard-allowlan@file` middleware
- Host-networked, static ports: 3200 (http), 4317 (otlp-grpc),
  4318 (otlp-http), 9411 (zipkin), 14268 (jaeger http), 14250 (jaeger grpc)

## Placement

- Pinned to `nomad-client-02` (constraint `node.unique.name = nomad-client-02`)
- Co-located with Loki

## Dependencies

- Host volume `/opt/nomad/data/tempo` (init-storage prestart chowns to
  10001:10001)
- Prometheus `prometheus.service.consul:9090/api/v1/write` for RED-metric
  remote write
- Grafana (TraceQL query layer)

## Notable configuration

- Block storage: S3 via the s3-orchestrator `tempo-traces` virtual bucket,
  reached over HTTPS at `s3.munchbox.cc/tempo-traces` (LAN-only Traefik router,
  no oauth2). HTTPS is required so minio-go signs UNSIGNED-PAYLOAD -- the gateway
  rejects minio-go's signed-streaming over plain HTTP. WAL + live-store stay on
  local disk under `/opt/nomad/data/tempo`.
- Retention 30 days (720h) via compactor `block_retention`; compaction must stay
  enabled (it is what enforces retention -- a disabled compactor never deletes)
- Metrics generator runs service-graphs, span-metrics; service graph dimensions
  include `http.method` and `http.status_code`
- gRPC server intentionally on 9196 to avoid the historical 9095 collision
  (was Promtail; now Alloy)
- 800 MHz / 1 GiB reservation, 2 GiB memory cap
