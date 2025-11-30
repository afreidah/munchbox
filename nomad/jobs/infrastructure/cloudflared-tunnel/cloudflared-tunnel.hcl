# -------------------------------------------------------------------------------
# Cloudflared Tunnel — Cloudflare Zero Trust Tunnel
#
# Project: Munchbox / Author: Alex Freidah
#
# Secure tunnel exposing internal services to the internet via Cloudflare's
# network. Routes traffic for alexfreidah.com and subdomains through Traefik.
# Credentials stored securely in Vault.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "cloudflared-tunnel"
type  = "service"
image = "cloudflare/cloudflared:latest"
port  = 2000
host_network = true
size = "tiny"

# --- Storage ---
storage = "ephemeral"

# --- Vault integration ---
vault = true

# --- Container arguments ---
args = ["tunnel", "--config", "/secrets/config.yml", "run"]

# --- Configuration templates ---
templates = [
  { src = "credentials.json.tpl", dest = "/local/credentials.json", vault = true },
  { src = "config.yml.tpl", dest = "/local/config.yml", vault = true }
]

# --- Health check ---
health_type = "http"
health_path = "/ready"

# --- Service tags ---
tags = ["infrastructure", "cloudflare", "tunnel", "ingress"]

# --- Termination ---
kill_timeout = "30s"
