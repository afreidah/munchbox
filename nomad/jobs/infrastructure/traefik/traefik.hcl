# PACK: traefik-ingress
# -------------------------------------------------------------------------------
# Traefik Ingress Controller — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# System job for HTTPS-first reverse proxy with Consul service discovery.
# Auto-generates self-signed certificates for *.munchbox domains on first run.
# Dashboard on :8081 (LAN-only) for traffic analysis and metrics.
# -------------------------------------------------------------------------------

job_name        = "traefik"
region          = "global"
datacenters     = ["pi-dc"]
node_pool       = "core"
priority        = 50
traefik_version = "v3.6.1"

traefik_version      = "v3.5.3"
ingress_node_constraint = "ingress"
certificate_cn       = "*.munchbox"
certificate_days     = 3650

dashboard_port = 8081
http_port      = 80
https_port     = 443

consul_address    = "127.0.0.1:8500"
consul_token_path = "kv/data/traefik"

cpu    = 200
memory = 256

vault_enabled = true
vault_role    = "nomad-workloads"
