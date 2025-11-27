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
