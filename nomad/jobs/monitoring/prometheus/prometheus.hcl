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
image = "prom/prometheus:v3.10.0"
port  = 9090
static_port = 9090
host_network = true
type  = "system"
size  = "medium"

# --- Placement: ingress nodes only ---
# TODO(wg-ha): the backup ingress node's wg0 has the 10.200.0.0/24 route
# but no learned peer endpoints, so its prometheus instance can't reach
# Oracle exporters and false-alerts on a cascade. Real fix is to bring
# wg0 up only on the node currently holding the WG VIP (sync wg0 to the
# keepalived MASTER state via notify_master/notify_backup). Until then,
# expect spurious "Oracle scrape failed" alerts from the backup-ingress
# prometheus instance.
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
  "--storage.tsdb.retention.time=30d",
  "--storage.tsdb.wal-compression",
  "--web.page-title=Munchbox Prometheus",
  "--enable-feature=exemplar-storage"
]

# --- Configuration templates ---
templates = [
  { src = "prometheus.yml.tpl", dest = "/etc/prometheus/config/prometheus.yml", vault = true },
  { src = "alert_rules.yml", dest = "/etc/prometheus/config/alert_rules.yml", vault = false, change_mode = "signal" },
  { src = "consul_token.tpl", dest = "/etc/prometheus/secrets/consul_token", vault = true },
  { src = "vault_token.tpl", dest = "/etc/prometheus/secrets/vault_token", vault = true },
  { src = "nomad_token.tpl", dest = "/etc/prometheus/secrets/nomad_token", vault = true },
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
