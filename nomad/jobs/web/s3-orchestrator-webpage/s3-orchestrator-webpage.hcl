# -------------------------------------------------------------------------------
# s3-orchestrator-webpage — Project Documentation Website
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the s3-orchestrator Hugo project website. Public-facing via
# Cloudflare tunnel, no oauth2-proxy.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "s3-orchestrator-webpage"
type  = "service"
image = "registry.munchbox.cc/s3-orchestrator-web:v0.46.45"
port  = 80
node  = "any"
host_network = false
size  = "tiny"
count = 3
storage = "ephemeral"

# --- Placement: one instance per node ---
constraints = [
  { attribute = "", operator = "distinct_hosts", value = "true" }
]

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/"

# --- Service tags ---
tags = [
  "web",
  "s3-orchestrator",
  "documentation",
  "traefik.http.routers.s3orch-web.rule=Host(`s3-orchestrator.munchbox.cc`)",
  "traefik.http.routers.s3orch-web.entrypoints=web",
  "traefik.http.routers.s3orch-web.service=s3-orchestrator-webpage",
  "traefik.http.routers.s3orch-web.priority=100",
]
