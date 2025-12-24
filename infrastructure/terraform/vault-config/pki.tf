# -------------------------------------------------------------------------------
# Vault PKI Roles
#
# Project: Munchbox / Author: Alex Freidah
#
# Certificate roles for the intermediate CA. Services request certs via these
# roles using Nomad workload identity.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Traefik Role — Wildcard certs for *.munchbox.cc
# -------------------------------------------------------------------------

resource "vault_pki_secret_backend_role" "traefik" {
  backend = "pki_int"
  name    = "traefik"

  allowed_domains    = ["munchbox.cc"]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_localhost    = true
  allow_ip_sans      = true
  allow_glob_domains = true
  max_ttl            = "8760h"
  ttl                = "720h"
  require_cn         = false
}

# -------------------------------------------------------------------------
# PostgreSQL Role — Certs for Patroni cluster nodes
# -------------------------------------------------------------------------
#
# Enables TLS for PostgreSQL connections. Patroni nodes request certs with
# their Consul service names. Clients use sslmode=verify-ca with the CA cert.

resource "vault_pki_secret_backend_role" "postgres" {
  backend = "pki_int"
  name    = "postgres"

  allowed_domains = [
    "postgres-primary.service.consul",
    "postgres-replica.service.consul",
    "postgres.service.consul",
    "node.consul"
  ]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_localhost    = true
  allow_ip_sans      = true
  max_ttl            = "720h" # 30 days max
  ttl                = "72h"  # 3 day default, auto-renewed by Nomad
  key_type           = "rsa"
  key_bits           = 2048
  require_cn         = false
}
