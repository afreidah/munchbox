# -----------------------------------------------------------------------------
# FORGEJO SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Syncs secrets from Vault to Forgejo repository action secrets for CI/CD.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/forgejo-secrets"
}

inputs = {
  # --- forgejo provider auth (was in root.hcl's generate "providers") ---
  forgejo_host      = get_env("FORGEJO_HOST", "http://forgejo.service.consul:30028")
  forgejo_api_token = get_env("FORGEJO_API_TOKEN", "")

  vault_mount      = "secret"
  repository_owner = "alex"
  repository_name  = "munchbox"

  secrets = {
    "aptly-pass" = {
      vault_path  = "aptly"
      vault_field = "password"
      secret_name = "APTLY_PASS"
    }
    "nomad-token" = {
      vault_path  = "nomad/management-token"
      vault_field = "token"
      secret_name = "NOMAD_TOKEN"
    }
    "consul-token" = {
      vault_path  = "consul/bootstrap-token"
      vault_field = "token"
      secret_name = "CONSUL_HTTP_TOKEN"
    }
    "vault-token" = {
      vault_path  = "ci-runner"
      vault_field = "token"
      secret_name = "VAULT_TOKEN"
    }
    "vault-addr" = {
      vault_path  = "ci-runner"
      vault_field = "addr"
      secret_name = "VAULT_ADDR"
    }
  }
}
