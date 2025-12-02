# -------------------------------------------------------------------------------
# PostgreSQL Shared — Multi-tenant Database Server
#
# Project: Munchbox / Author: Alex Freidah
#
# Shared PostgreSQL instance for multiple services (Temporal, rreading-glasses).
# Vault database secrets engine generates dynamic credentials per service.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name         = "postgres-shared"
type         = "service"
image        = "postgres:16-alpine"
port         = 5432
static_port  = 5432
host_network = true
node         = "nomad-client-03"
size         = "xlarge"

# --- Storage ---
storage      = "local"
storage_path = "/var/lib/postgresql/data"

# --- Vault integration ---
vault = true

# --- Templates ---
templates = [
  { src = "postgres.env.tpl", env = true, vault = true }
]

# --- Traefik routing ---
traefik      = true
traefik_host = "postgres-shared.munchbox.cc"

# --- Health check ---
register_service = true
health_type      = "tcp"
health_path      = ""

# --- Service tags ---
tags = ["database", "postgres", "shared"]

# --- Termination ---
kill_timeout = "60s"
kill_signal  = "SIGTERM"
