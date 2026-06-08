# -------------------------------------------------------------------------------
# Vault Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# Access policies for infrastructure components and Nomad workloads. Policies
# are defined via the vault_policies input variable from root.hcl.
#
# The nomad-workloads policy is special - it dynamically generates paths from
# the workload_secrets list and PKI role names.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# VAULT POLICIES (from map)
# -------------------------------------------------------------------------

resource "vault_policy" "policy" {
  for_each = var.policies_enabled ? var.vault_policies : {}

  name   = each.key
  policy = each.value.policy
}

# -------------------------------------------------------------------------
# NOMAD WORKLOADS POLICY (special - uses templating)
# -------------------------------------------------------------------------
# Grants access to secrets for Nomad jobs using workload identity.
# Dynamically includes paths for all workload_secrets and PKI roles.

resource "vault_policy" "nomad_workloads" {
  count = var.policies_enabled && length(var.workload_secrets) > 0 ? 1 : 0
  name  = "nomad-workloads"

  policy = <<EOT
# --- KV Secrets ---
%{for secret in var.workload_secrets~}
path "secret/data/${secret}" {
  capabilities = ["read"]
}
%{endfor~}

path "sys/metrics" {
  capabilities = ["read"]
}

# --- PKI Certificate Issuance (only roles Nomad workloads self-issue) ---
%{for role, cfg in var.pki_roles~}%{if contains(cfg.issued_by, "nomad")~}
path "${var.pki_backend_path}/issue/${role}" {
  capabilities = ["create", "update", "read"]
}
%{endif~}%{endfor~}

path "${var.pki_backend_path}/cert/ca" {
  capabilities = ["read"]
}

# --- Consul Dynamic Tokens ---
path "consul/creds/*" {
  capabilities = ["read"]
}

# --- SSH Client Certificate Signing ---
%{if var.ssh_ca_enabled~}
path "ssh-client-signer/sign/client-service" {
  capabilities = ["create", "update"]
}

path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}

path "ssh-host-signer/config/ca" {
  capabilities = ["read"]
}
%{endif~}
EOT
}

# -------------------------------------------------------------------------
# IMAGE SIGNING POLICY (for CI runners using cosign)
# -------------------------------------------------------------------------

resource "vault_policy" "image_signing" {
  count = var.policies_enabled && var.transit_enabled ? 1 : 0
  name  = "image-signing"

  policy = <<EOT
# Allow reading the cosign public key
path "transit/keys/cosign" {
  capabilities = ["read"]
}

# Allow signing with the cosign key
path "transit/sign/cosign" {
  capabilities = ["create", "update"]
}

# Allow verifying signatures (for image verification)
path "transit/verify/cosign" {
  capabilities = ["create", "update"]
}
EOT
}

# -------------------------------------------------------------------------
# VAULT-CERT-MANAGER POLICY (special - generated from pki_roles)
# -------------------------------------------------------------------------
# Used by the vault-cert-manager daemon's AppRole. Issue paths are generated
# from the roles tagged issued_by = ["cert-manager"]; the static tail covers
# CA reads and the SSH host-cert signing the daemon also performs.

resource "vault_policy" "cert_manager" {
  count = var.policies_enabled ? 1 : 0
  name  = "vault-cert-manager"

  policy = <<EOT
# --- PKI Certificate Issuance (roles the cert-manager daemon issues) ---
%{for role, cfg in var.pki_roles~}%{if contains(cfg.issued_by, "cert-manager")~}
path "${var.pki_backend_path}/issue/${role}" {
  capabilities = ["create", "update"]
}
%{endif~}%{endfor~}
path "${var.pki_backend_path}/cert/ca" {
  capabilities = ["read"]
}

# --- SSH host-cert signing + CA reads ---
path "ssh-host-signer/sign/host-signer" {
  capabilities = ["create", "update"]
}
path "ssh-host-signer/config/ca" {
  capabilities = ["read"]
}
path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}
EOT
}

# --- adopt the formerly hardcoded policy's state instead of destroy/create ---
moved {
  from = vault_policy.policy["vault-cert-manager"]
  to   = vault_policy.cert_manager[0]
}
