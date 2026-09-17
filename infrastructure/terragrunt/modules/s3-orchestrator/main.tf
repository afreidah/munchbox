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

# An identity may hold more than one grant, and the orchestrator keys a grant by
# user, kind and name rather than by an id of its own, so that triple is what
# for_each has to be keyed on too.
locals {
  grants = {
    for g in flatten([
      for identity, i in var.identities : [
        for grant in i.grants : {
          identity    = identity
          kind        = grant.kind == null ? "bucket" : grant.kind
          name        = grant.name
          permissions = grant.permissions
        }
      ]
    ]) : "${g.identity}/${g.kind}/${g.name == null ? "" : g.name}" => g
  }
}

resource "s3orchestrator_grant" "this" {
  for_each = local.grants

  user_id     = s3orchestrator_user.this[each.value.identity].id
  kind        = each.value.kind
  name        = each.value.name
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
