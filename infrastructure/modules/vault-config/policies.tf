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

# --- PKI Certificate Issuance ---
%{for role in keys(var.pki_roles)~}
path "${var.pki_backend_path}/issue/${role}" {
  capabilities = ["create", "update", "read"]
}
%{endfor~}

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
