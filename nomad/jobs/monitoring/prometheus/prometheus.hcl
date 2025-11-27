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
name  = "prometheus"
image = "prom/prometheus:v2.54.1"
port  = 9090
static_port = 9090
host_network = true
node  = "goren"
size  = "medium"
user  = "root"
vault = true

# --- Storage ---
volumes = [
  "/opt/nomad/data/prometheus:/opt/nomad/data/prometheus-data"
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
  "--storage.tsdb.retention.time=30d",
  "--storage.tsdb.wal-compression",
  "--web.page-title=Munchbox Prometheus"
]

# --- Configuration templates ---
templates = [
  { src = "prometheus.yml", dest = "/etc/prometheus/config/prometheus.yml", vault = false },
  { src = "alert_rules.yml", dest = "/etc/prometheus/config/alert_rules.yml", vault = false, change_mode = "signal" },
  { src = "consul_token.tpl", dest = "/etc/prometheus/secrets/consul_token", vault = true },
  { src = "vault_token.tpl", dest = "/etc/prometheus/secrets/vault_token", vault = true },
]

# --- Termination ---
kill_timeout = "60s"

# --- Service tags ---
tags = ["monitoring", "prometheus", "metrics"]
