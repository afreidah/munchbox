# -------------------------------------------------------------------------------
# VAULT-CONFIG ENV HELPER
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures Vault secrets engines, auth backends, policies, PKI roles, SSH
# CA, transit, JWT workload identity, and the AppRole for chef-managed nodes.
# Feature flags at the top of inputs gate each subsystem.
# -------------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/vault-config"
}

inputs = {
  # --- Feature flags ---
  kv_enabled               = true
  consul_secrets_enabled   = true
  jwt_auth_enabled         = true
  database_secrets_enabled = false
  pki_roles_enabled        = true
  policies_enabled         = true
  transit_enabled          = true
  ssh_ca_enabled           = true

  # --- Consul secrets engine ---
  consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
  consul_address         = "http://192.168.68.61:8500"

  # --- JWT auth for Nomad workload identity ---
  nomad_jwks_url = "https://192.168.68.61:4646/.well-known/jwks.json"

  # --- PKI Roles ---
  pki_roles = {
    "traefik" = {
      allowed_domains    = ["munchbox.cc"]
      allow_glob_domains = true
      max_ttl            = "8760h"
      ttl                = "720h"
    }

    "postgres" = {
      allowed_domains = [
        "postgres-primary.service.consul",
        "postgres-replica.service.consul",
        "haproxy-postgres.service.consul",
        "postgres.service.consul",
        "node.consul"
      ]
      max_ttl  = "720h"
      ttl      = "72h"
      key_bits = 2048
    }
  }

  # --- Vault Policies ---
  vault_policies = {
    "consul-token-read" = {
      policy = <<-EOT
        path "secret/data/consul/*" {
          capabilities = ["read"]
        }
      EOT
    }

    "nomad-server" = {
      policy = <<-EOT
        path "secret/data/consul/nomad-server-token" {
          capabilities = ["read"]
        }
        path "pki_int/issue/nomad-server" {
          capabilities = ["create", "update"]
        }
      EOT
    }

    "nomad-client" = {
      policy = <<-EOT
        path "secret/data/consul/nomad-client-token" {
          capabilities = ["read"]
        }
        path "pki_int/issue/nomad-client" {
          capabilities = ["create", "update"]
        }
      EOT
    }

    "vault-cert-manager" = {
      policy = <<-EOT
        path "pki_int/issue/consul-server" {
          capabilities = ["create", "update"]
        }
        path "pki_int/issue/consul-client" {
          capabilities = ["create", "update"]
        }
        path "pki_int/issue/nomad-server" {
          capabilities = ["create", "update"]
        }
        path "pki_int/issue/nomad-client" {
          capabilities = ["create", "update"]
        }
        path "pki_int/cert/ca" {
          capabilities = ["read"]
        }
        path "ssh-host-signer/sign/host-signer" {
          capabilities = ["create", "update"]
        }
        path "ssh-host-signer/config/ca" {
          capabilities = ["read"]
        }
        path "ssh-client-signer/config/ca" {
          capabilities = ["read"]
        }
      EOT
    }

    "backup-worker" = {
      policy = <<-EOT
        path "sys/storage/raft/snapshot" {
          capabilities = ["read"]
        }
      EOT
    }

    "ssh-client-user" = {
      policy = <<-EOT
        path "ssh-client-signer/sign/client-user" {
          capabilities = ["create", "update"]
        }
        path "ssh-host-signer/config/ca" {
          capabilities = ["read"]
        }
      EOT
    }
  }

  # --- Workload Secrets (for nomad-workloads policy) ---
  workload_secrets = [
    "traefik",
    "grafana",
    "backup-worker",
    "prometheus",
    "prometheus-nomad",
    "nomad-ui",
    "alertmanager",
    "redis-shared",
    "postgres-shared/root",
    "postgres-shared/replication",
    "deluge",
    "pia",
    "mullvad",
    "cloudflared",
    "cloudflare",
    "cloudflare-wandns",
    "cloudflare-logcollector",
    "aptly-admin",
    "vaultwarden",
    "temporal",
    "trivy-dashboard",
    "forgejo",
    "forgejo-runner",
    "github/moat-runner",
    "umami",
    "minio",
    "s3-orchestrator",
    "flight-fetcher",
    "patroni",
    "oauth2-proxy",
    "traefik-log-dashboard",
    "maxmind",
    "oracle-watchdog",
    "proxmox",
    "aptly",
    "immich",
    "redis",
    "haproxy",
    "zfswatcher",
    "consul/backup-worker-token",
    "ssh/backup-worker",
    "sonarr",
    "radarr",
    "lidarr",
    "readarr",
    "prowlarr",
    "g3",
    "wireguard",
    "pihole/green"
  ]

  # --- AppRole auth for chef-managed nodes ---
  approle_auth_enabled = true
  chef_managed_node_secrets = [
    # cinc_server-related (admin password, validator pem, trusted cert)
    "cinc-server/admin/*",
    "cinc-server/validator",
    "cinc-server/trusted-cert",
    # wireguard mesh keys (per node, both public + private)
    "wireguard-v2/*",
    # consul agent ACL token (consul/* deliberately NOT listed -- bootstrap-token would be exposed)
    "consul/agent-token",
    # consul ACL token used by nomad workloads via the local consul agent's `tokens.default` slot; broader KV/service read than the agent token
    "consul/nomad-client-token",
    # consul ACL token for oracle-watchdog (session-heartbeat scope; per-service token, not the broad agent-token)
    "consul/oracle-watchdog-token",
    # nomad management ACL token for the auto-restart-webhook receiver (stabler-only at runtime, but policy is fleet-wide; narrower per-job-restart token is a hardening item)
    "nomad/management-token",
    # consul ACL token vault servers use to write to vault/ KV in consul storage backend (vault-storage policy); only the 3 vault servers actually need this but policy is fleet-wide
    "consul/vault-storage-token",
    # vault-cert-manager AppRole creds (role_id is semi-public; secret_id is sensitive, both required to auth)
    "vault-cert-manager/role-id",
    "vault-cert-manager/secret-id",
    # SSH break-glass pubkey (added to root's authorized_keys by munchbox_base::sshd ssh_ca path)
    "ssh/break-glass",
    # zfswatcher http auth proxy password hash (rubirosa only at runtime, fleet-wide policy)
    "proxmox/zfswatcher-proxy",
  ]

  # --- Non-KV Vault reads chef-managed nodes need (SSH signer CA pubkeys). ---
  chef_managed_node_extra_paths = [
    {
      path         = "ssh-client-signer/config/ca"
      capabilities = ["read"]
    },
    {
      path         = "ssh-host-signer/config/ca"
      capabilities = ["read"]
    },
  ]

  # --- Database Roles (disabled by default) ---
  database_roles = {
    "temporal" = {
      creation_statements = [
        "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
        "GRANT ALL PRIVILEGES ON DATABASE temporal TO \"{{name}}\";",
        "GRANT ALL ON SCHEMA public TO \"{{name}}\";"
      ]
    }
    "kanboard" = {
      creation_statements = [
        "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
        "GRANT CONNECT ON DATABASE kanboard TO \"{{name}}\";",
        "GRANT USAGE, CREATE ON SCHEMA public TO \"{{name}}\";",
        "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
        "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
        "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"{{name}}\";",
        "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"{{name}}\";"
      ]
    }
  }

  # --- Workload Vault Roles (per-job JWT auth) ---
  workload_vault_roles = {
    "s3-orchestrator" = {
      policies = ["nomad-workloads", "s3-orchestrator-transit"]
      bound_claims = {
        nomad_job_id = "s3-orchestrator"
      }
    }
    "flight-fetcher" = {
      policies = ["nomad-workloads"]
      bound_claims = {
        nomad_job_id = "flight-fetcher"
      }
    }
  }

  # --- Service Tokens ---
  service_tokens = {
    "ci-runner" = {
      policies   = ["image-signing"]
      vault_path = "ci-runner"
      ttl        = "8760h"
      extra_data = {
        addr = "https://vault.munchbox.cc:8200"
      }
    }
  }
}
