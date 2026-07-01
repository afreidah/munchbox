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

    # --- restart-only: `nomad job restart` needs read-job + alloc-lifecycle, nothing else ---
    "auto-restart-webhook" = {
      description = "AlertManager webhook receiver - restart jobs only"
      rules_hcl   = <<-EOT
        namespace "*" {
          policy       = "read"
          capabilities = ["alloc-lifecycle"]
        }
      EOT
    }

    # --- runner autoscaler: dispatch ci-runner + deregister (reap) it ---
    "ci-runner-scaler" = {
      description = "Temporal runner autoscaler - dispatch + reap ephemeral CI runners"
      rules_hcl   = <<-EOT
        namespace "default" {
          policy       = "read"
          capabilities = ["dispatch-job", "submit-job"]
        }
      EOT
    }

    # --- ci-runner: server-side `nomad job validate`/`plan` from CI. submit-job
    #     is the capability the validate/plan endpoints require; read lists jobs. ---
    "ci-runner" = {
      description = "CI runner - validate/plan Nomad jobs against the live server"
      rules_hcl   = <<-EOT
        namespace "default" {
          policy       = "read"
          capabilities = ["submit-job"]
        }
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
    "auto-restart-webhook" = {
      policies = ["auto-restart-webhook"]
    }
    "ci-runner-scaler" = {
      policies = ["ci-runner-scaler"]
    }
    "ci-runner" = {
      policies = ["ci-runner"]
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
    "auto-restart-webhook" = {
      vault_path       = "nomad/auto-restart-webhook"
      token_key        = "auto-restart-webhook"
      token_field_name = "token"
    }
    "ci-runner-scaler" = {
      vault_path       = "ci-runner-scaler"
      token_key        = "ci-runner-scaler"
      token_field_name = "nomad_token"
    }
    # --- ci-runner-nomad, not ci-runner: secret/ci-runner is the image-signing
    #     Vault token (service_tokens in vault-config); keep the KV paths distinct. ---
    "ci-runner" = {
      vault_path       = "ci-runner-nomad"
      token_key        = "ci-runner"
      token_field_name = "nomad_token"
    }
  }
}
