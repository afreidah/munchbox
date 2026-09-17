# -----------------------------------------------------------------------------
# FORGEJO SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Syncs secrets from Vault to Forgejo repository action secrets for CI/CD.
#
# Path-keyed on the leaf dir name: one leaf per Forgejo repository, because the
# module manages a single repository's secrets. The leaf name is the repository
# name, so a new repository is a new leaf and nothing here changes.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/forgejo-secrets"
}

locals {
  leaf = basename(get_terragrunt_dir())

  # The first leaf is named for the service rather than the repository it
  # targets. Mapping it here keeps its state key where it is; every other leaf
  # is named for its repository.
  repository = lookup({ "forgejo" = "munchbox" }, local.leaf, local.leaf)

  # --- The app repositories publish .deb packages to aptly on a release tag.
  #     Publishing is HTTP against aptly's API, so the runner needs the password
  #     and nothing else -- these repositories get no cluster credentials.
  #
  #     aptly-admin, not aptly: aptly-secrets.hcl generates the API password and
  #     its bcrypt htpasswd into aptly-admin, and that is what the API's nginx
  #     validates against. secret/aptly belongs to the s3 gateway. ---
  aptly_secrets = {
    "aptly-pass" = {
      vault_path  = "aptly-admin"
      vault_field = "password"
      secret_name = "APTLY_PASS"
    }
    # --- Publishes build artifacts to the orchestrator's S3 surface on a
    #     release. The identity is granted list, read and write on the one
    #     bucket, so a runner holding it reaches no other. Every repository in
    #     this set gets it, which is wider than the one that publishes needs. ---
    "artifacts-access-key" = {
      vault_path  = "s3-identity/artifacts_s3o_writer"
      vault_field = "access_key"
      secret_name = "AWS_ACCESS_KEY_ID"
    }
    "artifacts-secret-key" = {
      vault_path  = "s3-identity/artifacts_s3o_writer"
      vault_field = "secret_key"
      secret_name = "AWS_SECRET_ACCESS_KEY"
    }
  }

  munchbox_secrets = {
    "aptly-pass" = {
      vault_path  = "aptly-admin"
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

inputs = {
  # --- forgejo provider auth (was in root.hcl's generate "providers") ---
  forgejo_host      = get_env("FORGEJO_HOST", "http://forgejo.service.consul:30028")
  forgejo_api_token = get_env("FORGEJO_API_TOKEN", "")

  vault_mount      = "secret"
  repository_owner = "alex"
  repository_name  = local.repository

  secrets = local.repository == "munchbox" ? local.munchbox_secrets : local.aptly_secrets
}
