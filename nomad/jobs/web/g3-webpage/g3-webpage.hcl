# -------------------------------------------------------------------------------
# g3-webpage — Project Documentation Website
#
# Project: Munchbox / Author: Alex Freidah
#
# Serves the g3 Hugo project website. Public-facing via Cloudflare tunnel,
# no oauth2-proxy.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "g3-webpage"
type  = "service"
image = "registry.munchbox.cc/g3-web:v0.5.1"
port  = 80
node  = "any"
host_network = false
size   = "tiny"
cpu    = 50
memory = 32
count  = 3
storage = "ephemeral"

# --- Placement: one instance per node, keep off ingress nodes ---
constraints = [
  { attribute = "", operator = "distinct_hosts", value = "true" },
  { attribute = "$${meta.role}", operator = "!=", value = "ingress" }
]

# --- Vault integration ---
vault = false

# --- Traefik integration ---
traefik = true
health_path = "/"

# --- Service tags ---
tags = [
  "web",
  "g3",
  "documentation",
  "traefik.http.routers.g3-web.rule=Host(`g3.munchbox.cc`)",
  "traefik.http.routers.g3-web.entrypoints=web",
  "traefik.http.routers.g3-web.service=g3-webpage",
  "traefik.http.routers.g3-web.priority=100",
]
