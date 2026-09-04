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
# NOMAD WORKLOAD SELF-SCOPED POLICY
# -------------------------------------------------------------------------
# Read on the job's own KV prefix, and nothing else. The JWT role sets
# user_claim = /nomad_job_id, so a token's entity-alias name is the job id
# and Vault resolves the template per request. One policy therefore covers
# every job whose secrets live under secret/data/<job id>, with no per-job
# path list to maintain.
#
# The accessor has to appear literally in the policy body -- Vault does not
# accept a mount path there -- so it is interpolated from the backend rather
# than hardcoded.

resource "vault_policy" "nomad_workload_self" {
  count = var.policies_enabled && var.jwt_auth_enabled ? 1 : 0
  name  = "nomad-workload-self"

  policy = <<-EOT
    # --- The job's own KV prefix ---
    path "secret/data/{{identity.entity.aliases.${vault_jwt_auth_backend.nomad[0].accessor}.name}}" {
      capabilities = ["read"]
    }

    path "secret/data/{{identity.entity.aliases.${vault_jwt_auth_backend.nomad[0].accessor}.name}}/*" {
      capabilities = ["read"]
    }

    path "secret/metadata/{{identity.entity.aliases.${vault_jwt_auth_backend.nomad[0].accessor}.name}}/*" {
      capabilities = ["list"]
    }

    # --- CA chain, needed by any task rendering a cert bundle ---
    path "${var.pki_backend_path}/cert/ca" {
      capabilities = ["read"]
    }
  EOT
}

# -------------------------------------------------------------------------
# PER-JOB EXTRA-GRANT POLICIES
# -------------------------------------------------------------------------
# A job whose every read sits under its own prefix needs nothing here --
# nomad-workload-self covers it. These are the jobs reading someone else's
# secret: a credential shared with another job, or one whose name predates
# the job's. Naming the paths per job keeps them off every other workload.

resource "vault_policy" "workload_extra" {
  for_each = var.policies_enabled ? var.workload_extra_secrets : {}

  name = "${each.key}-secrets"

  policy = join("\n\n", concat(
    [
      for secret in each.value.secrets :
      "path \"secret/data/${secret}\" {\n  capabilities = [\"read\"]\n}"
    ],
    [
      for path, caps in each.value.extra_paths :
      "path \"${path}\" {\n  capabilities = ${jsonencode(caps)}\n}"
    ]
  ))
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
