# -------------------------------------------------------------------------------
# nomad-temporal-jobs-webpage — Project Documentation Website
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the nomad-temporal-jobs Hugo project website. Public-facing via
# Cloudflare tunnel, no oauth2-proxy.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "nomad-temporal-jobs-webpage"
type  = "service"
image = "registry.munchbox.cc/temporal-workers-web:v0.2.6"
port  = 80
node  = "any"
host_network = false
size   = "tiny"
cpu    = 50
memory = 32
count  = 3
storage = "ephemeral"

# --- Placement: one instance per node, avoid oracle nodes ---
constraints = [
  { attribute = "", operator = "distinct_hosts", value = "true" },
  { attribute = "$${node.unique.name}", operator = "!=", value = "oraclenode1" },
  { attribute = "$${node.unique.name}", operator = "!=", value = "oraclenode2" }
]

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/"

# --- Service tags ---
tags = [
  "web",
  "nomad-temporal-jobs",
  "documentation",
  "traefik.http.routers.ntj-web.rule=Host(`nomad-temporal-jobs.munchbox.cc`)",
  "traefik.http.routers.ntj-web.entrypoints=web",
  "traefik.http.routers.ntj-web.service=nomad-temporal-jobs-webpage",
  "traefik.http.routers.ntj-web.priority=100",
]
