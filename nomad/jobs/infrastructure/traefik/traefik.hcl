# -------------------------------------------------------------------------------
# Traefik Ingress Controller — Consul Connect Service Mesh Gateway
#
# Project: Munchbox / Author: Alex Freidah
#
# System job for HTTPS-first reverse proxy with Consul Connect service mesh
# integration. Routes external traffic into service mesh via authenticated mTLS
# connections. Auto-generates self-signed certificates for *.munchbox domains.
# Dashboard on :8081 (LAN-only) for traffic analysis.
# -------------------------------------------------------------------------------

# PACK: traefik-ingress

# -----------------------------------------------------------------------------
# Core Configuration
# -----------------------------------------------------------------------------

job_name   = "traefik"
region     = "global"
datacenters = ["pi-dc"]
node_pool  = "core"
priority   = 50

# -----------------------------------------------------------------------------
# Traefik Configuration
# -----------------------------------------------------------------------------

traefik_version         = "v3.6.1"
ingress_node_constraint = "ingress"
certificate_cn          = "*.munchbox"
certificate_days        = 3650

# -----------------------------------------------------------------------------
# Port Configuration
# -----------------------------------------------------------------------------

dashboard_port = 8081
http_port      = 80
https_port     = 443

# -----------------------------------------------------------------------------
# Consul Integration
# -----------------------------------------------------------------------------

consul_address    = "127.0.0.1:8500"
consul_token_path = "kv/data/traefik"

# -----------------------------------------------------------------------------
# Consul Connect Service Mesh
# -----------------------------------------------------------------------------

connect_aware      = false
connect_by_default = false
exposed_by_default = false

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------

cpu    = 200
memory = 256

# -----------------------------------------------------------------------------
# Vault Integration
# -----------------------------------------------------------------------------

vault_enabled = true
vault_role    = "nomad-workloads"
