# -------------------------------------------------------------------------------
# Vault PKI Roles
#
# Project: Munchbox / Author: Alex Freidah
#
# Certificate roles for the intermediate CA. Services request certificates via
# these roles using Nomad workload identity or vault-cert-manager.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# TRAEFIK ROLE
# -------------------------------------------------------------------------
# Wildcard certificates for *.munchbox.cc domains. Used by Traefik for TLS
# termination on internal services.

resource "vault_pki_secret_backend_role" "traefik" {
  count   = var.pki_roles_enabled ? 1 : 0
  backend = var.pki_backend_path
  name    = "traefik"

  allowed_domains    = var.traefik_allowed_domains
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
# POSTGRESQL ROLE
# -------------------------------------------------------------------------
# Certificates for Patroni cluster nodes. Enables TLS for PostgreSQL
# connections with certificate verification.

resource "vault_pki_secret_backend_role" "postgres" {
  count   = var.pki_roles_enabled ? 1 : 0
  backend = var.pki_backend_path
  name    = "postgres"

  allowed_domains    = var.postgres_allowed_domains
  allow_subdomains   = true
  allow_bare_domains = true
  allow_localhost    = true
  allow_ip_sans      = true
  max_ttl            = "720h"
  ttl                = "72h"
  key_type           = "rsa"
  key_bits           = 2048
  require_cn         = false
}
