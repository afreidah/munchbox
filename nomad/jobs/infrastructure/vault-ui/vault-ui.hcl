# -------------------------------------------------------------------------------
# Vault UI — Web Interface for HashiCorp Vault
#
# Project: Munchbox / Author: Alex Freidah
#
# Web-based interface for browsing and managing Vault secrets, policies, and
# tokens. Users authenticate through the UI using their preferred Vault auth
# method (token, LDAP, GitHub, etc.).
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "vault-ui"
type         = "service"
image        = "djenriquez/vault-ui"
port         = 8000
host_network = true
size         = "small"

# --- Placement (amd64 only - no ARM image available) ---
node         = "nomad-client-01"

# --- Storage ---
storage = "ephemeral"

# --- Traefik routing ---
traefik      = true
traefik_host = "vault-ui.munchbox.cc"

# --- Health check ---
health_path = "/"

# --- Environment variables ---
env = {
  # Vault server URL (must include protocol)
  VAULT_URL_DEFAULT            = "https://192.168.68.61:8200"
  # Default auth method shown in UI
  VAULT_AUTH_DEFAULT           = "TOKEN"
  # Listen port (default 8000)
  PORT                         = "8000"
  # Accept self-signed certificates
  NODE_TLS_REJECT_UNAUTHORIZED = "0"
  # Timezone
  TZ                           = "America/Los_Angeles"
}

# --- Service tags ---
tags = [
  "vault-ui",
  "vault",
  "ui",
  "infrastructure",
  "traefik.http.routers.vault-ui.middlewares=oauth2-proxy@file",
  # HTTP router for CF tunnel
  "traefik.http.routers.vault-ui-http.rule=Host(`vault-ui.munchbox.cc`)",
  "traefik.http.routers.vault-ui-http.entrypoints=web",
  "traefik.http.routers.vault-ui-http.middlewares=cf-tunnel-https@file,oauth2-proxy@file"
]

# --- Termination ---
kill_timeout = "30s"
