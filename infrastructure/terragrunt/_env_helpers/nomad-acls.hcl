# -----------------------------------------------------------------------------
# NOMAD-ACLS ENV HELPER
# -----------------------------------------------------------------------------
#
# Provisions Nomad ACL policies + tokens and stashes generated tokens in
# Vault KV. Operator policies (admin/read-only/developer) don't get tokens
# minted -- they're for human SSO via the UI.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//nomad-acls"
}

inputs = {
  nomad_bootstrap_token = get_env("NOMAD_TOKEN", "")
  vault_mount           = "secret"

  # --- ACL Policies (operator + service) ---
  policies = {
    "admin" = {
      description = "Full cluster administration access"
      rules_hcl   = <<-EOT
        namespace "*" {
          policy       = "write"
          capabilities = ["alloc-exec", "alloc-node-exec", "alloc-lifecycle"]
        }
        node { policy = "write" }
        agent { policy = "write" }
        operator { policy = "write" }
        plugin { policy = "read" }
        host_volume "*" { policy = "write" }
      EOT
    }

    "read-only" = {
      description = "Read-only cluster monitoring access"
      rules_hcl   = <<-EOT
        namespace "*" { policy = "read" }
        node { policy = "read" }
        agent { policy = "read" }
      EOT
    }

    "developer" = {
      description = "Job management in default namespace"
      rules_hcl   = <<-EOT
        namespace "default" {
          policy       = "write"
          capabilities = ["alloc-exec", "alloc-lifecycle"]
        }
        node { policy = "read" }
        agent { policy = "read" }
        host_volume "*" { policy = "read" }
      EOT
    }

    "backup-worker" = {
      description = "Temporal backup worker - snapshot and read access"
      rules_hcl   = <<-EOT
        namespace "*" { policy = "read" }
        node { policy = "read" }
        agent { policy = "write" }
        operator { policy = "write" }
      EOT
    }

    "prometheus" = {
      description = "Prometheus metrics scraping access"
      rules_hcl   = <<-EOT
        namespace "*" { policy = "read" }
        node { policy = "read" }
        agent { policy = "read" }
      EOT
    }
  }

  # --- ACL Tokens (services only; operator policies are SSO-attached) ---
  tokens = {
    "backup-worker" = {
      type     = "management"
      policies = []
    }
    "prometheus" = {
      policies = ["prometheus"]
    }
    "nomad-ui" = {
      type     = "management"
      policies = []
    }
  }

  # --- Vault Secret Storage ---
  vault_secrets = {
    "backup-worker" = {
      vault_path       = "backup-worker"
      token_key        = "backup-worker"
      token_field_name = "nomad_token"
    }
    "prometheus" = {
      vault_path       = "prometheus-nomad"
      token_key        = "prometheus"
      token_field_name = "nomad_token"
    }
    "nomad-ui" = {
      vault_path       = "nomad-ui"
      token_key        = "nomad-ui"
      token_field_name = "token"
    }
  }
}
