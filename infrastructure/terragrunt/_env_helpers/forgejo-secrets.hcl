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
    # --- Scoped to what the post-merge deploy actually does: submit Nomad jobs,
    #     and write the commit it deployed to one Consul key prefix. These were
    #     the Nomad management token and the Consul bootstrap token, which any
    #     workflow on the repo could read, on a runner holding the Docker
    #     socket. A Forgejo action secret is a row in a Postgres database
    #     running on the cluster it grants access to, so what lives here should
    #     be the least that works. ---
    "nomad-token" = {
      vault_path  = "forgejo-ci-runner-nomad"
      vault_field = "nomad_token"
      secret_name = "NOMAD_TOKEN"
    }
    "consul-token" = {
      vault_path  = "consul/forgejo-ci-runner-token"
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
