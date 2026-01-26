# -------------------------------------------------------------------------------
# Tempo — Distributed Tracing Backend
#
# Project: Munchbox / Author: Alex Freidah
#
# Grafana Tempo provides distributed tracing storage and querying. Receives traces
# from Traefik via OpenTelemetry (OTLP) protocol. Queryable through Grafana with
# TraceQL for request flow visualization across services.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "tempo"
image        = "grafana/tempo:2.9.1"
port         = 3200
static_port  = 3200
host_network = true
node         = "nomad-client-02"  # Same node as Loki for observability stack
size         = "medium"
memory       = 700
cpu          = 400

# --- Storage (trace data) ---
storage       = "local"
storage_path  = "/var/tempo"
storage_owner = "10001:10001"

# --- Traefik routing ---
traefik      = true
traefik_host = "tempo.munchbox"

# --- Health check ---
health_path = "/ready"

# --- Environment ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Container arguments ---
args = ["-config.file=/etc/tempo/config.yaml"]

# --- Configuration templates ---
templates = [
  { src = "config.yaml", dest = "/etc/tempo/config.yaml" }
]

# --- Service tags ---
tags = ["logging", "tempo", "tracing", "observability"]

# --- Additional ports for trace ingestion ---
extra_ports = [
  { name = "otlp-grpc",    port = "4317",  static = "true" },
  { name = "otlp-http",    port = "4318",  static = "true" },
  { name = "zipkin",       port = "9411",  static = "true" },
  { name = "jaeger-http",  port = "14268", static = "true" },
  { name = "jaeger-grpc",  port = "14250", static = "true" }
]
