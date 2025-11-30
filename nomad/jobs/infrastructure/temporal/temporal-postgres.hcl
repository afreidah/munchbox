# -------------------------------------------------------------------------------
# Temporal PostgreSQL Database — Persistent Backend for Workflow Engine
#
# Project: Munchbox / Author: Alex Freidah
#
# PostgreSQL 15 backend for Temporal workflow orchestration. Persistent storage
# on stabler node with local volume mount. Auto-creates both required databases.
# -------------------------------------------------------------------------------

# --- General Settings ---
name  = "temporal-postgres"
type  = "service"
image = "postgres:15-alpine"
port  = 5432
static_port = 5432
host_network = true
node = "stabler.munchbox.cc"
size = "medium"

# --- Storage ---
storage = "local"
storage_path = "/var/lib/postgresql/data"

# --- Environment variables ---
env = {
  TZ                = "UTC"
  POSTGRES_USER     = "temporal"
  POSTGRES_PASSWORD = "temporal"
  POSTGRES_DB       = "temporal"
}

# --- Configuration templates ---
templates = [
  { src = "init-db.sql", dest = "/docker-entrypoint-initdb.d/init.sql" }
]

# --- Traefik integration ---
traefik = false

# --- Service registration ---
register_service = true

# --- Health check (disabled for PostgreSQL) ---
health_type = "none"

# --- Service tags ---
tags = [
  "temporal",
  "postgres",
  "database"
]

# --- Resources override ---
cpu = 500
memory = 512

# --- DNS configuration ---
dns = ["192.168.68.62", "192.168.68.64"]
