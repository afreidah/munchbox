# -------------------------------------------------------------------------------
# Redis Exporter — Cache/Message Broker Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports Redis metrics for Prometheus scraping. Connects to redis-primary
# via Consul DNS. Password retrieved from Vault at runtime.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "redis-exporter"
image       = "oliver006/redis_exporter:v1.80.1"
port        = 9121
static_port = 9121
size        = "small"
vault       = true

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/metrics"

# --- Environment (static) ---
env = {
  TZ                   = "America/Los_Angeles"
  REDIS_ADDR           = "redis-primary.service.consul:6379"
}

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "redis.env", dest = "secrets/redis.env", env = true }
]

# --- Service tags ---
tags = ["monitoring", "redis-exporter", "metrics", "database"]
