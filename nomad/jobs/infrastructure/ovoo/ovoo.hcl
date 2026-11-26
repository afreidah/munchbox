# -------------------------------------------------------------------------------
# ovoo -- Web UI for the Nomad cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Browser and phone UI for jobs, allocations, nodes, storage and ACLs, with task
# logs and a terminal. Each user signs in with their own Nomad ACL token, which
# ovoo keeps in an httpOnly cookie and forwards to the Nomad API over TLS.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name  = "ovoo"
image = "ghcr.io/ingvarch/ovoo:v0.7.0"
port  = 3000
size  = "small"
vault = true

# --- Traefik routing ---
traefik      = true
traefik_host = "ovoo.munchbox.cc"

# --- Health check (unauthenticated config endpoint) ---
health_path = "/api/config"

# --- Environment (static; TICKET_SECRET comes via template) ---
env = {
  NOMAD_ADDR          = "https://nomad.service.consul:4646"
  NODE_EXTRA_CA_CERTS = "/etc/ovoo/certs/ca-chain.crt"
}

# --- Vault template renders the exec-ticket HMAC key into env ---
templates = [
  { src = "ovoo.env", dest = "secrets/ovoo.env", env = true }
]

# --- Full chain: Bun rejects an intermediate-only trust anchor ---
volumes = [
  "/etc/nomad.d/tls/ca-chain.crt:/etc/ovoo/certs/ca-chain.crt:ro"
]

# --- Placement: any on-prem nomad client (NOT oracle) ---
constraints = [
  { attribute = "$${meta.cloud}", operator = "!=", value = "oracle" }
]
