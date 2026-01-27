# -------------------------------------------------------------------------------
# Vault PKI Roles
#
# Project: Munchbox / Author: Alex Freidah
#
# Certificate roles for the intermediate CA. Services request certificates via
# these roles using Nomad workload identity or vault-cert-manager. Roles are
# defined via the pki_roles input variable from root.hcl.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# PKI ROLES
# -------------------------------------------------------------------------

resource "vault_pki_secret_backend_role" "role" {
  for_each = var.pki_roles_enabled ? var.pki_roles : {}

  backend = var.pki_backend_path
  name    = each.key

  allowed_domains    = each.value.allowed_domains
  allow_subdomains   = each.value.allow_subdomains
  allow_bare_domains = each.value.allow_bare_domains
  allow_localhost    = each.value.allow_localhost
  allow_ip_sans      = each.value.allow_ip_sans
  allow_glob_domains = each.value.allow_glob_domains
  max_ttl            = each.value.max_ttl
  ttl                = each.value.ttl
  key_type           = each.value.key_type
  key_bits           = each.value.key_bits
  require_cn         = each.value.require_cn
}
