# -----------------------------------------------------------------------------
# CONSUL-ACLS ENV HELPER
# -----------------------------------------------------------------------------
#
# Provisions Consul ACL policies + tokens and stashes generated tokens in
# Vault KV. One entry per service in `acl_entries`; the locals block fans
# the entry out into the policies / tokens / vault_secrets maps the module
# expects.
#
# Per-entry shape:
#   description       (required) -- policy description
#   token_description (required) -- token description (kept separate; many differ
#                                   from the policy description for legacy reasons)
#   rules             (required) -- HCL rules string
#   vault_path        (optional, default "consul/<key>-token") -- KV path
#   token_field_name  (optional, default "token")              -- field in the KV item
#   include_accessor  (optional, default true)                 -- write accessor_id alongside
#   no_token          (optional, default false)                -- skip token + vault_secret entirely
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//consul-acls"
}

locals {
  acl_entries = {
    "nomad-server" = {
      description       = "Nomad server - full cluster orchestration"
      token_description = "Token for Nomad servers"
      rules             = <<-EOT
        agent_prefix "" { policy = "read" }
        node_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
        acl = "write"
        query_prefix "" { policy = "read" }
        key_prefix "" { policy = "write" }
      EOT
    }

    "nomad-client" = {
      description       = "Nomad client - service registration and node updates"
      token_description = "Token for Nomad clients"
      rules             = <<-EOT
        agent_prefix "" { policy = "read" }
        node_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
        key_prefix "" { policy = "read" }
      EOT
    }

    "vault-storage" = {
      description       = "Vault storage backend"
      token_description = "Token for Vault storage backend"
      rules             = <<-EOT
        key_prefix "vault/" { policy = "write" }
        node_prefix "" { policy = "write" }
        service "vault" { policy = "write" }
        agent_prefix "" { policy = "write" }
        session_prefix "" { policy = "write" }
      EOT
    }

    # --- consul-agent breaks the "consul/<key>-token" default (uses "consul/agent-token") ---
    "consul-agent" = {
      description       = "Consul agent - self registration and services"
      token_description = "Token for Consul client agents"
      vault_path        = "consul/agent-token"
      rules             = <<-EOT
        node_prefix "" { policy = "write" }
        agent_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
      EOT
    }

    "traefik" = {
      description       = "Traefik - Consul Catalog service discovery"
      token_description = "Token for Traefik reverse proxy"
      vault_path        = "traefik"
      token_field_name  = "consul_token"
      include_accessor  = false
      rules             = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        agent_prefix "" { policy = "read" }
      EOT
    }

    "prometheus" = {
      description       = "Prometheus - service discovery and metrics collection"
      token_description = "Token for Prometheus service discovery"
      vault_path        = "prometheus"
      token_field_name  = "consul_token"
      include_accessor  = false
      rules             = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        agent_prefix "" { policy = "read" }
      EOT
    }

    "patroni" = {
      description       = "Patroni - PostgreSQL HA cluster coordination"
      token_description = "Token for Patroni PostgreSQL HA cluster"
      vault_path        = "patroni"
      token_field_name  = "consul_token"
      rules             = <<-EOT
        session_prefix "" { policy = "write" }
        key_prefix "service/munchbox-postgres" { policy = "write" }
        service_prefix "postgres" { policy = "write" }
        service "patroni" { policy = "write" }
        node_prefix "" { policy = "read" }
      EOT
    }

    "haproxy" = {
      description       = "HAProxy - database failover proxy service discovery"
      token_description = "Token for HAProxy database failover proxy"
      vault_path        = "haproxy"
      token_field_name  = "consul_token"
      rules             = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
      EOT
    }

    # --- policy-only, no token minted, no vault_secret ---
    "health-checks" = {
      description = "Health checks - service and Vault startup operations"
      no_token    = true
      rules       = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        key_prefix "vault" { policy = "read" }
      EOT
    }

    "terraform-ci" = {
      description       = "Terraform CI - state storage and locking"
      token_description = "Token for CI/CD terraform state management"
      rules             = <<-EOT
        key_prefix "terraform/" { policy = "write" }
        session_prefix "" { policy = "write" }
      EOT
    }

    "oracle-watchdog" = {
      description       = "Oracle Watchdog - node health monitoring via sessions"
      token_description = "Token for Oracle Watchdog node monitors"
      rules             = <<-EOT
        session_prefix "" { policy = "write" }
        key_prefix "oracle-watchdog/" { policy = "write" }
      EOT
    }

    "backup-worker" = {
      description       = "Backup worker - Consul snapshot access"
      token_description = "Token for backup worker Consul snapshots"
      token_field_name  = "consul_token"
      include_accessor  = false
      rules             = <<-EOT
        acl = "write"
        key_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        service_prefix "" { policy = "read" }
        session_prefix "" { policy = "read" }
        agent_prefix "" { policy = "read" }
        operator = "read"
      EOT
    }
  }

  # --- fan acl_entries out into the three module-shape maps ---
  policies = {
    for k, v in local.acl_entries :
    k => { description = v.description, rules = v.rules }
  }

  tokens = {
    for k, v in local.acl_entries :
    k => { description = v.token_description, policies = [k] }
    if !try(v.no_token, false)
  }

  vault_secrets = {
    for k, v in local.acl_entries :
    k => merge(
      {
        vault_path = try(v.vault_path, "consul/${k}-token")
        token_key  = k
      },
      try(v.token_field_name, null) != null ? { token_field_name = v.token_field_name } : {},
      try(v.include_accessor, null) != null ? { include_accessor_id = v.include_accessor } : {},
    )
    if !try(v.no_token, false)
  }
}

inputs = {
  consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
  vault_mount            = "secret"
  policies               = local.policies
  tokens                 = local.tokens
  vault_secrets          = local.vault_secrets
}
