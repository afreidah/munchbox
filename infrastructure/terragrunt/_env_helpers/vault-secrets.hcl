# -----------------------------------------------------------------------------
# VAULT SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Single home for writing generated secrets to Vault. The secret structure is
# declared in the vault_secrets map below; each entry names a generator leaf
# (source), a key into that generator's vault_data, and optional static
# non-secret values to merge. Adding a secret is a map entry (+ one dependency
# block here if it introduces a new generator).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//vault-kv-secrets"
}

dependency "cloudflare_tokens" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/global/secrets/cloudflare-tokens"

  mock_outputs = {
    vault_data = {
      wandns       = { api_token = "mock-wandns-token" }
      logcollector = { api_token = "mock-logcollector-token" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "aptly_secrets" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/global/secrets/aptly"

  mock_outputs = {
    vault_data = { admin = { password = "mock-aptly-password", htpasswd = "admin:mock-bcrypt-hash" } }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "access_keys" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/global/secrets/access-keys"

  mock_outputs = {
    vault_data = {
      "s3-bucket/unified" = { access_key = "MOCKUNIFIEDACCESSKEY", secret_key = "mock-unified-secret-key" }
      "s3-bucket/aptly"   = { access_key = "MOCKAPTLYACCESSKEY", secret_key = "mock-aptly-secret-key" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- source = generator leaf; key = index into its vault_data; static =
  #     non-secret values merged in (keyed to match the Vault data keys). ---
  vault_secrets = {
    "aptly-admin" = {
      source = "aptly_secrets"
      key    = "admin"
    }
    "cloudflare-wandns" = {
      source = "cloudflare_tokens"
      key    = "wandns"
      static = { zone_id = local.root.locals.cloudflare_munchbox_zone_id }
    }
    "cloudflare-logcollector" = {
      source = "cloudflare_tokens"
      key    = "logcollector"
    }
    "s3-bucket/unified" = {
      source = "access_keys"
      key    = "s3-bucket/unified"
    }
    "s3-bucket/aptly" = {
      source = "access_keys"
      key    = "s3-bucket/aptly"
    }
  }
}

# --- dependency outputs can only be referenced from inputs, not locals; map
#     source name -> generator vault_data and index by key, merging statics ---
inputs = {
  secrets = {
    for name, s in local.vault_secrets :
    name => {
      data = merge(
        try(s.static, {}),
        {
          aptly_secrets     = dependency.aptly_secrets.outputs.vault_data
          cloudflare_tokens = dependency.cloudflare_tokens.outputs.vault_data
          access_keys       = dependency.access_keys.outputs.vault_data
        }[s.source][s.key],
      )
    }
  }
}
