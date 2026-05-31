# -------------------------------------------------------------------------------
# Pi-hole Exporter — Metrics for both Pi-hole instances over the LAN
#
# Project: Munchbox / Author: Alex Freidah
#
# Single eko/pihole-exporter instance scraping green + logan via comma-separated
# PIHOLE_HOSTNAME. Replaces the on-pi-1 binaries that ansible installed and
# that v6 broke (armv6 vs GOARM=7 vs Pi-hole v6 REST API rewrite).
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "pihole-exporter"
image       = "ekofr/pihole-exporter:v1.2.0"
port        = 9617
static_port = 9617
size        = "tiny"
memory      = 64
vault       = true

# --- Traefik routing ---
traefik = false

# --- Health check (eko's /metrics scrapes pihole synchronously, ~3s per hit) ---
health_path     = "/metrics"
health_timeout  = "10s"
health_interval = "30s"

# --- Environment (static; secrets come via template) ---
env = {
  TZ                = "America/Los_Angeles"
  PIHOLE_HOSTNAME   = "192.168.68.62,192.168.68.64"
  PIHOLE_PROTOCOL   = "http"
  PIHOLE_PORT       = "80"
  PORT              = "9617"
}

# --- Vault template renders the password into env at runtime ---
templates = [
  { src = "pihole.env", dest = "secrets/pihole.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "pihole-exporter", "metrics", "scrape-interval=30s", "scrape-timeout=25s"]

# --- Placement: any on-prem nomad client (NOT oracle). Needs LAN access to
#     192.168.68.62/64; routing through the WG tunnel from oracle is pointless. ---
node = "any"
constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }
]
