# -----------------------------------------------------------------------------
# S3-ORCHESTRATOR MODULE
# -----------------------------------------------------------------------------
#
# Declares the identities a running s3-orchestrator authorizes requests against,
# and puts the keypair it mints for each one into Vault where the consuming job
# reads it. Onboarding a client is a map entry rather than a sequence of admin
# commands somebody remembers running.
#
# The resources are declared here rather than pulled from the module the
# s3-orchestrator repository ships, because every module in this repository is
# self-contained and the supply-chain checks refuse a remote source. The version
# boundary is the provider pin in versions.tf, which is the one that matters.
#
# Buckets stay out: the ones a deployment serves are declared in its config file
# and the admin API refuses to change them.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER CREDENTIALS
# -----------------------------------------------------------------------------

# --- the deployment's root keypair, which every call below signs as ---
data "vault_kv_secret_v2" "root" {
  mount = var.vault_mount
  name  = var.root_credential_path
}

provider "s3orchestrator" {
  address           = var.address
  access_key_id     = data.vault_kv_secret_v2.root.data[var.root_key_field]
  secret_access_key = data.vault_kv_secret_v2.root.data[var.root_secret_field]
}

# -----------------------------------------------------------------------------
# IDENTITIES
# -----------------------------------------------------------------------------

resource "s3orchestrator_user" "this" {
  for_each = var.identities

  name = each.key
}

# --- no keypair given, so the orchestrator mints one ---
resource "s3orchestrator_credential" "this" {
  for_each = var.identities

  user_id = s3orchestrator_user.this[each.key].id
  label   = each.value.label
}

# --- one bucket per identity, so the grant needs no flattening ---
resource "s3orchestrator_grant" "this" {
  for_each = var.identities

  user_id     = s3orchestrator_user.this[each.key].id
  name        = each.value.bucket
  permissions = each.value.permissions
}

# -----------------------------------------------------------------------------
# KEYPAIR DELIVERY
# -----------------------------------------------------------------------------

# --- the minted secret crosses the wire once, so Vault is where it lands ---
resource "vault_kv_secret_v2" "identity" {
  for_each = var.identities

  mount = var.vault_mount
  name  = "${var.vault_prefix}/${each.key}"

  # Field names match what the config-declared bucket credentials already used,
  # so a consuming job changes the path it reads and nothing else.
  data_json = jsonencode({
    access_key = s3orchestrator_credential.this[each.key].access_key_id
    secret_key = s3orchestrator_credential.this[each.key].secret_access_key
  })
}
