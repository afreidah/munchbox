# -------------------------------------------------------------------------------
# Prometheus — Metrics Collection and Alerting
#
# Project: Munchbox / Author: Alex Freidah
#
# Time-series metrics database with dynamic Consul service discovery and alert
# evaluation. Scrapes infrastructure services including Nomad, Consul, Vault,
# and node exporters. Forwards alerts to Alertmanager for notification routing.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "prometheus"
image        = "prom/prometheus:v3.12.0"
port         = 9090
static_port  = 9090
host_network = true
type         = "system"
size         = "medium"

# --- Placement: both ingress nodes ---
# Restored to type=system on the ingress role after issue #70 (reverse-WG
# cutover) gave both ingresses independent active WG sessions to every
# Oracle. The nc05 replica can now scrape Oracle targets normally.
constraints = [
  { attribute = "$${meta.role}", operator = "=", value = "ingress" }
]
vault = true

# --- Storage ---
volumes = [
  "/opt/nomad/data/prometheus:/opt/nomad/data/prometheus-data",
  "/etc/nomad.d/tls/ca-chain.crt:/etc/prometheus/certs/ca-chain.crt:ro"
]

# --- Traefik routing ---
traefik      = true
traefik_host = "prometheus.munchbox.cc"

# --- Health check ---
health_path = "/-/ready"

# --- Environment ---
env = {
  TZ                              = "America/Los_Angeles"
  CONSUL_HTTP_ADDR                = "127.0.0.1:8500"
  PROMETHEUS_WEB_ENABLE_LIFECYCLE = "true"
  PROMETHEUS_WEB_ENABLE_ADMIN_API = "true"
}

# --- Container arguments ---
args = [
  "--config.file=/etc/prometheus/config/prometheus.yml",
  "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
  "--web.listen-address=0.0.0.0:9090",
  "--web.enable-lifecycle",
  "--web.enable-admin-api",
  "--web.enable-remote-write-receiver",
  "--storage.tsdb.retention.time=14d",
  "--storage.tsdb.wal-compression",
  "--web.page-title=Munchbox Prometheus",
  "--enable-feature=exemplar-storage"
]

# --- Configuration templates ---
templates = [
  { src = "prometheus.yml.tpl", dest = "/etc/prometheus/config/prometheus.yml", vault = true },
  { src = "alert_rules.yml", dest = "/etc/prometheus/config/alert_rules.yml", vault = false, change_mode = "signal" },
  # --- Token files are read per-scrape via credentials_file; noop stops a Vault-lease re-render from restarting prometheus ---
  { src = "consul_token.tpl", dest = "/etc/prometheus/secrets/consul_token", vault = true, change_mode = "noop" },
  { src = "vault_token.tpl", dest = "/etc/prometheus/secrets/vault_token", vault = true, change_mode = "noop" },
  { src = "nomad_token.tpl", dest = "/etc/prometheus/secrets/nomad_token", vault = true, change_mode = "noop" },
]

# --- Termination ---
kill_timeout = "60s"

# --- Service tags ---
tags = [
  "monitoring",
  "prometheus",
  "metrics",
  "traefik.http.routers.prometheus.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.prometheus-http.rule=Host(`prometheus.munchbox.cc`)",
  "traefik.http.routers.prometheus-http.entrypoints=web",
  "traefik.http.routers.prometheus-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file"
]
