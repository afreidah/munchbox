# -----------------------------------------------------------------------------
# FORGEJO SECRETS MODULE
# -----------------------------------------------------------------------------
#
# Manages Forgejo repository action secrets via the Forgejo API. Secrets are
# sourced from Vault KV and synced to Forgejo for use in CI/CD pipelines.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# REPOSITORY DATA SOURCE
# -----------------------------------------------------------------------------
# Look up the repository to get its numeric ID for secret management.

data "forgejo_repository" "repo" {
  owner = var.repository_owner
  name  = var.repository_name
}

# -----------------------------------------------------------------------------
# VAULT SECRETS
# -----------------------------------------------------------------------------
# Read secrets from Vault KV to sync to Forgejo.

data "vault_kv_secret_v2" "secrets" {
  for_each = var.secrets

  mount = var.vault_mount
  name  = each.value.vault_path
}

# -----------------------------------------------------------------------------
# FORGEJO ACTION SECRETS
# -----------------------------------------------------------------------------
# Create action secrets in the repository for CI/CD pipelines.

resource "forgejo_repository_action_secret" "secrets" {
  for_each = var.secrets

  repository_id = data.forgejo_repository.repo.id
  name          = each.value.secret_name
  data          = data.vault_kv_secret_v2.secrets[each.key].data[each.value.vault_field]
}
