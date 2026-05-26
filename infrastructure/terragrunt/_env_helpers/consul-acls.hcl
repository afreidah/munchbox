# -----------------------------------------------------------------------------
# CONSUL-ACLS ENV HELPER
# -----------------------------------------------------------------------------
#
# Provisions Consul ACL policies + tokens and stashes the generated tokens
# in Vault KV. Data lives here (policies/tokens/vault_secrets shape is
# consul-acls-specific and isn't reused elsewhere).
#
# A future tightening pass could collapse the three parallel maps into one
# per-service entry; left alone for now to keep the plan-clean baseline.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//consul-acls"
}

inputs = {
  consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
  vault_mount            = "secret"

  # --- ACL Policies ---
  policies = {
    "nomad-server" = {
      description = "Nomad server - full cluster orchestration"
      rules       = <<-EOT
        agent_prefix "" { policy = "read" }
        node_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
        acl = "write"
        query_prefix "" { policy = "read" }
        key_prefix "" { policy = "write" }
      EOT
    }

    "nomad-client" = {
      description = "Nomad client - service registration and node updates"
      rules       = <<-EOT
        agent_prefix "" { policy = "read" }
        node_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
        key_prefix "" { policy = "read" }
      EOT
    }

    "vault-storage" = {
      description = "Vault storage backend"
      rules       = <<-EOT
        key_prefix "vault/" { policy = "write" }
        node_prefix "" { policy = "write" }
        service "vault" { policy = "write" }
        agent_prefix "" { policy = "write" }
        session_prefix "" { policy = "write" }
      EOT
    }

    "consul-agent" = {
      description = "Consul agent - self registration and services"
      rules       = <<-EOT
        node_prefix "" { policy = "write" }
        agent_prefix "" { policy = "write" }
        service_prefix "" { policy = "write" }
      EOT
    }

    "traefik" = {
      description = "Traefik - Consul Catalog service discovery"
      rules       = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        agent_prefix "" { policy = "read" }
      EOT
    }

    "prometheus" = {
      description = "Prometheus - service discovery and metrics collection"
      rules       = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        agent_prefix "" { policy = "read" }
      EOT
    }

    "patroni" = {
      description = "Patroni - PostgreSQL HA cluster coordination"
      rules       = <<-EOT
        session_prefix "" { policy = "write" }
        key_prefix "service/munchbox-postgres" { policy = "write" }
        service_prefix "postgres" { policy = "write" }
        service "patroni" { policy = "write" }
        node_prefix "" { policy = "read" }
      EOT
    }

    "haproxy" = {
      description = "HAProxy - database failover proxy service discovery"
      rules       = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
      EOT
    }

    "health-checks" = {
      description = "Health checks - service and Vault startup operations"
      rules       = <<-EOT
        service_prefix "" { policy = "read" }
        node_prefix "" { policy = "read" }
        key_prefix "vault" { policy = "read" }
      EOT
    }

    "terraform-ci" = {
      description = "Terraform CI - state storage and locking"
      rules       = <<-EOT
        key_prefix "terraform/" { policy = "write" }
        session_prefix "" { policy = "write" }
      EOT
    }

    "oracle-watchdog" = {
      description = "Oracle Watchdog - node health monitoring via sessions"
      rules       = <<-EOT
        session_prefix "" { policy = "write" }
        key_prefix "oracle-watchdog/" { policy = "write" }
      EOT
    }

    "backup-worker" = {
      description = "Backup worker - Consul snapshot access"
      rules       = <<-EOT
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

  # --- ACL Tokens ---
  tokens = {
    "nomad-server" = {
      description = "Token for Nomad servers"
      policies    = ["nomad-server"]
    }
    "nomad-client" = {
      description = "Token for Nomad clients"
      policies    = ["nomad-client"]
    }
    "vault-storage" = {
      description = "Token for Vault storage backend"
      policies    = ["vault-storage"]
    }
    "consul-agent" = {
      description = "Token for Consul client agents"
      policies    = ["consul-agent"]
    }
    "traefik" = {
      description = "Token for Traefik reverse proxy"
      policies    = ["traefik"]
    }
    "prometheus" = {
      description = "Token for Prometheus service discovery"
      policies    = ["prometheus"]
    }
    "patroni" = {
      description = "Token for Patroni PostgreSQL HA cluster"
      policies    = ["patroni"]
    }
    "haproxy" = {
      description = "Token for HAProxy database failover proxy"
      policies    = ["haproxy"]
    }
    "terraform-ci" = {
      description = "Token for CI/CD terraform state management"
      policies    = ["terraform-ci"]
    }
    "oracle-watchdog" = {
      description = "Token for Oracle Watchdog node monitors"
      policies    = ["oracle-watchdog"]
    }
    "backup-worker" = {
      description = "Token for backup worker Consul snapshots"
      policies    = ["backup-worker"]
    }
  }

  # --- Vault Secret Storage ---
  vault_secrets = {
    "nomad-server" = {
      vault_path = "consul/nomad-server-token"
      token_key  = "nomad-server"
    }
    "nomad-client" = {
      vault_path = "consul/nomad-client-token"
      token_key  = "nomad-client"
    }
    "vault-storage" = {
      vault_path = "consul/vault-storage-token"
      token_key  = "vault-storage"
    }
    "consul-agent" = {
      vault_path = "consul/agent-token"
      token_key  = "consul-agent"
    }
    "traefik" = {
      vault_path          = "traefik"
      token_key           = "traefik"
      token_field_name    = "consul_token"
      include_accessor_id = false
    }
    "prometheus" = {
      vault_path          = "prometheus"
      token_key           = "prometheus"
      token_field_name    = "consul_token"
      include_accessor_id = false
    }
    "patroni" = {
      vault_path       = "patroni"
      token_key        = "patroni"
      token_field_name = "consul_token"
    }
    "haproxy" = {
      vault_path       = "haproxy"
      token_key        = "haproxy"
      token_field_name = "consul_token"
    }
    "terraform-ci" = {
      vault_path = "consul/terraform-ci-token"
      token_key  = "terraform-ci"
    }
    "oracle-watchdog" = {
      vault_path = "consul/oracle-watchdog-token"
      token_key  = "oracle-watchdog"
    }
    "backup-worker" = {
      vault_path          = "consul/backup-worker-token"
      token_key           = "backup-worker"
      token_field_name    = "consul_token"
      include_accessor_id = false
    }
  }
}
