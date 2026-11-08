# -------------------------------------------------------------------------------
# Vault PKI Roles
#
# Project: Munchbox / Author: Alex Freidah
#
# Intermediate CAs signed by the root, and the certificate roles on them.
# Services request certificates via these roles using Nomad workload identity
# or vault-cert-manager. pki and pki_int predate this module and are not
# managed here; pki_intermediates adds CAs beside pki_int, each trusted only
# for what it issues.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# INTERMEDIATE CAS
# -------------------------------------------------------------------------

# --- The mount's max lease is the CA's lifetime, so no leaf outlives it ---
resource "vault_mount" "intermediate" {
  for_each = var.pki_intermediates

  path                  = each.key
  type                  = "pki"
  description           = "Intermediate CA: ${each.value.common_name}"
  max_lease_ttl_seconds = each.value.ttl
}

# --- internal: Vault generates the key and keeps it; only the CSR leaves ---
resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  for_each = var.pki_intermediates

  backend     = vault_mount.intermediate[each.key].path
  type        = "internal"
  common_name = each.value.common_name
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  for_each = var.pki_intermediates

  backend     = var.pki_root_path
  csr         = vault_pki_secret_backend_intermediate_cert_request.intermediate[each.key].csr
  common_name = each.value.common_name
  ttl         = tostring(each.value.ttl)
}

# --- The bundle carries the root too, so ca_chain resolves as it does on pki_int ---
resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  for_each = var.pki_intermediates

  backend     = vault_mount.intermediate[each.key].path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate[each.key].certificate_bundle
}

# -------------------------------------------------------------------------
# PKI ROLES
# -------------------------------------------------------------------------

resource "vault_pki_secret_backend_role" "role" {
  for_each = var.pki_roles_enabled ? var.pki_roles : {}

  backend = coalesce(each.value.backend, var.pki_backend_path)
  name    = each.key

  # --- A role on a new intermediate must wait for its mount to hold a CA ---
  depends_on = [vault_pki_secret_backend_intermediate_set_signed.intermediate]

  allowed_domains             = each.value.allowed_domains
  allow_any_name              = each.value.allow_any_name
  allow_subdomains            = each.value.allow_subdomains
  allow_bare_domains          = each.value.allow_bare_domains
  allow_localhost             = each.value.allow_localhost
  allow_ip_sans               = each.value.allow_ip_sans
  allow_glob_domains          = each.value.allow_glob_domains
  allow_wildcard_certificates = each.value.allow_wildcard_certificates
  enforce_hostnames           = each.value.enforce_hostnames
  client_flag                 = each.value.client_flag
  server_flag                 = each.value.server_flag
  max_ttl                     = each.value.max_ttl
  ttl                         = each.value.ttl
  key_type                    = each.value.key_type
  key_bits                    = each.value.key_bits
  require_cn                  = each.value.require_cn
}
