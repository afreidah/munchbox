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

locals {
  # --- shared base for the consul/nomad mTLS cert roles: allow_any_name, no domain restriction, ttl unset so the cert-manager's requested ttl governs ---
  cert_role_base = {
    allowed_domains             = []
    allow_any_name              = true
    allow_subdomains            = false
    allow_bare_domains          = false
    allow_glob_domains          = false
    allow_localhost             = true
    allow_ip_sans               = true
    allow_wildcard_certificates = true
    enforce_hostnames           = true
    client_flag                 = true
    server_flag                 = true
    require_cn                  = true
    key_type                    = "rsa"
    key_bits                    = 2048
    ttl                         = "0"
    max_ttl                     = tostring(8760 * 3600)
    issued_by                   = ["cert-manager"]
  }


  # --- Per-job grants: everything a job reads outside its own
  #     secret/data/<job id> prefix. Each entry becomes a <job>-secrets policy
  #     bound to that job's role, so a shared credential reaches only the jobs
  #     that name it. Jobs absent from this map read nothing but their own
  #     prefix, via the templated nomad-workload-self policy. ---
  workload_extra_secrets = {
    "aptly"                    = { secrets = ["aptly-admin", "s3-bucket/aptly"] }
    "aptly-s3-gateway"         = { secrets = ["aptly"] }
    "backup-worker"            = { secrets = ["consul/backup-worker-token", "postgres-shared/root", "s3-bucket/unified"] }
    "cloudflare-log-collector" = { secrets = ["cloudflare-logcollector"] }
    "deluge"                   = { secrets = ["mullvad"] }
    "forgejo"                  = { secrets = ["redis-shared"] }
    "g3-proxy"                 = { secrets = ["g3"] }
    "gitgogit"                 = { secrets = ["forgejo"] }
    "github-runner-moat"       = { secrets = ["github/moat-runner"] }
    "github-runner-moat-vm"    = { secrets = ["github/moat-runner"] }
    "haproxy"                  = { secrets = ["redis-shared"] }
    "oracle-watchdog"          = { secrets = ["cloudflare-wandns"] }
    "pihole-exporter"          = { secrets = ["pihole/green"] }
    "prometheus"               = { secrets = ["aptly-admin", "dnsdist", "prometheus-nomad"] }
    "pve-exporter"             = { secrets = ["proxmox"] }
    "redis-sentinel"           = { secrets = ["redis-shared"] }
    "tempo"                    = { secrets = ["s3-bucket/tempo-traces"] }
    "temporal-schema"          = { secrets = ["temporal"] }
    "temporal-server"          = { secrets = ["temporal"] }
    "traefik-log-dashboard"    = { secrets = ["maxmind"] }
    "trivy-scan-worker"        = { secrets = ["backup-worker", "trivy-dashboard"] }
    "trivy-server"             = { secrets = ["redis-shared"] }

    # --- traefik proxies these services and injects their credentials as
    #     basic-auth headers, so it reads secrets it does not own. ---
    "traefik" = {
      secrets = ["cloudflared", "dnsdist", "nomad-ui", "traefik-log-dashboard", "zfswatcher"]
    }

    # --- patroni self-issues the Postgres server cert on top of the shared
    #     superuser and replication credentials. ---
    "patroni" = {
      secrets     = ["postgres-shared/replication", "postgres-shared/root"]
      extra_paths = { "pki_int/issue/postgres" = ["create", "update", "read"] }
    }

    # --- s3-orchestrator fronts every bucket, so it holds all three keys. ---
    "s3-orchestrator" = {
      secrets = ["s3-bucket/aptly", "s3-bucket/tempo-traces", "s3-bucket/unified"]
    }
  }

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
      max_ttl            = tostring(8760 * 3600)
      ttl                = tostring(720 * 3600)
      issued_by          = ["nomad"]
    }

    "postgres" = {
      allowed_domains = [
        "postgres-primary.service.consul",
        "postgres-replica.service.consul",
        "haproxy-postgres.service.consul",
        "postgres.service.consul",
        "node.consul"
      ]
      max_ttl   = tostring(720 * 3600)
      ttl       = tostring(72 * 3600)
      key_bits  = 2048
      issued_by = ["nomad"]
    }

    # --- consul/nomad mTLS roles (adopted from the live unmanaged Vault roles) ---
    "consul-server" = local.cert_role_base
    "consul-client" = local.cert_role_base
    "nomad-server"  = local.cert_role_base
    "nomad-client"  = local.cert_role_base

    # --- vault-server: explicit allowed_domains, subdomains/bare/glob on, hostnames off, 1yr default ttl ---
    "vault-server" = {
      allowed_domains             = ["munchbox.cc", "munchbox", "vault.service.consul", "stabler", "goren", "debian", "nomad-server-03", "localhost"]
      allow_any_name              = true
      allow_subdomains            = true
      allow_bare_domains          = true
      allow_glob_domains          = true
      allow_localhost             = true
      allow_ip_sans               = true
      allow_wildcard_certificates = true
      enforce_hostnames           = false
      client_flag                 = true
      server_flag                 = true
      require_cn                  = true
      key_type                    = "rsa"
      key_bits                    = 2048
      ttl                         = "0"
      max_ttl                     = tostring(8760 * 3600)
      issued_by                   = ["cert-manager"]
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

    # --- cleanup-worker: the one workload that signs itself an SSH client cert,
    #     which it uses to reach nodes and prune their on-disk artifacts. That
    #     grant carries root and ubuntu as principals, so it lives here rather
    #     than in nomad-workloads where every job would hold it. Also reads the
    #     Postgres superuser for the database side of the same cleanup. ---
    "cleanup-worker" = {
      policy = <<-EOT
        path "ssh-client-signer/sign/client-service" {
          capabilities = ["create", "update"]
        }
        path "ssh-client-signer/config/ca" {
          capabilities = ["read"]
        }
        path "ssh-host-signer/config/ca" {
          capabilities = ["read"]
        }
        path "secret/data/ssh/backup-worker" {
          capabilities = ["read"]
        }
        path "secret/data/backup-worker" {
          capabilities = ["read"]
        }
        path "secret/data/postgres-shared/root" {
          capabilities = ["read"]
        }
      EOT
    }

    # --- media-import-worker: reads these three through its own Vault client
    #     at runtime rather than a template, so nothing in the job spec shows
    #     the dependency. deluge and jellyfin belong to those jobs; media-import
    #     is its own but sits outside its job-id prefix. ---
    "media-import-worker" = {
      policy = <<-EOT
        path "secret/data/media-import" {
          capabilities = ["read"]
        }
        path "secret/data/deluge" {
          capabilities = ["read"]
        }
        path "secret/data/jellyfin" {
          capabilities = ["read"]
        }
      EOT
    }

    # --- cert-acquirer-worker: the Temporal worker that issues the wildcard.
    #     Writes the published cert, the pre-publish staging copy, and the
    #     persisted ACME account; the Cloudflare token read comes from
    #     nomad-workloads (cloudflare-wandns is in workload_secrets). ---
    "cert-acquirer-worker" = {
      policy = <<-EOT
        path "secret/data/traefik/wildcard" {
          capabilities = ["create", "update", "read"]
        }
        path "secret/data/traefik/wildcard-staging" {
          capabilities = ["create", "update", "read"]
        }
        path "secret/data/traefik/acme-account" {
          capabilities = ["create", "update", "read"]
        }
      EOT
    }

    # --- github-token-renewer: reads the GitHub App private key to mint
    #     per-repo installation tokens, and the SonarCloud master token to mint
    #     a per-repo analysis token. ---
    "github-token-renewer" = {
      policy = <<-EOT
        path "secret/data/github/token-renewer-app" {
          capabilities = ["read"]
        }
        path "secret/data/sonarcloud/token" {
          capabilities = ["read"]
        }
      EOT
    }

    # --- ci-runner-scaler: reuses the token-renewer GitHub App (mints runner
    #     registration tokens, lists queued jobs) and reads its scoped Nomad ACL
    #     token (minted by nomad-acls -> secret/ci-runner-scaler) to dispatch the
    #     ephemeral ci-runner jobs. The App's installation must also grant
    #     Administration + Actions on GitHub (set on github.com, not here).
    #     Vault-mode repos the App can't reach (ev-the-dev/moat) are polled with a
    #     PAT read here from secret/github/moat-runner -- the same secret the
    #     static moat runners self-register with; the scaler only reads it. ---
    "ci-runner-scaler" = {
      policy = <<-EOT
        path "secret/data/github/token-renewer-app" {
          capabilities = ["read"]
        }
        path "secret/data/ci-runner-scaler" {
          capabilities = ["read"]
        }
        path "secret/data/github/moat-runner" {
          capabilities = ["read"]
        }
        path "secret/data/github/moat-poll" {
          capabilities = ["read"]
        }
      EOT
    }

    # --- ci-runner: the ephemeral CI runner reads only its scoped Nomad ACL
    #     token (minted by nomad-acls -> secret/ci-runner-nomad) to run
    #     `nomad job validate`/`plan`. terragrunt validate needs no secrets. ---
    "ci-runner" = {
      policy = <<-EOT
        path "secret/data/ci-runner-nomad" {
          capabilities = ["read"]
        }
      EOT
    }
  }

  workload_extra_secrets = local.workload_extra_secrets

  # --- nomad-workloads is retired: every job now reads through its own
  #     policy plus the templated nomad-workload-self. An empty list drops the
  #     policy entirely. ---
  workload_secrets = []

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
    # nomad restart-only ACL token for the auto-restart-webhook receiver (read + alloc-lifecycle, no management); stabler-only at runtime, policy is fleet-wide
    "nomad/auto-restart-webhook",
    # nomad serf gossip key; only the 3 servers render it, policy is fleet-wide
    "nomad/gossip-key",
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
  #     Generated from workload_extra_secrets: each such job gets a bound role
  #     carrying nomad-workload-self plus its own <job>-secrets policy. The
  #     explicit entries below are jobs that additionally need a hand-written
  #     policy (transit, SSH signing, an API credential set). Every other job
  #     uses the default nomad-workloads role, which carries only the template.
  workload_vault_roles = merge(
    {
      for job, cfg in local.workload_extra_secrets : job => {
        policies     = ["nomad-workload-self", "${job}-secrets"]
        bound_claims = { nomad_job_id = job }
      }
    },
    {
      "s3-orchestrator" = {
        policies     = ["nomad-workload-self", "s3-orchestrator-secrets", "s3-orchestrator-transit"]
        bound_claims = { nomad_job_id = "s3-orchestrator" }
      }
      "cleanup-worker" = {
        policies     = ["nomad-workload-self", "cleanup-worker"]
        bound_claims = { nomad_job_id = "cleanup-worker" }
      }
      "media-import-worker" = {
        policies     = ["nomad-workload-self", "media-import-worker"]
        bound_claims = { nomad_job_id = "media-import-worker" }
      }
      "cert-acquirer-worker" = {
        policies     = ["nomad-workload-self", "cert-acquirer-worker"]
        bound_claims = { nomad_job_id = "cert-acquirer-worker" }
      }
      "github-token-renewer" = {
        policies     = ["nomad-workload-self", "github-token-renewer"]
        bound_claims = { nomad_job_id = "github-token-renewer" }
      }
      "ci-runner-scaler" = {
        policies     = ["nomad-workload-self", "ci-runner-scaler"]
        bound_claims = { nomad_job_id = "ci-runner-scaler" }
      }
      "ci-runner" = {
        policies     = ["nomad-workload-self", "ci-runner"]
        bound_claims = { nomad_job_id = "ci-runner" }
      }
    }
  )

  # --- Service Tokens ---
  service_tokens = {
    "ci-runner" = {
      policies   = ["image-signing"]
      vault_path = "ci-runner"
      # --- vault_token stores the duration string as-given (unlike pki/ssh roles which store seconds) ---
      ttl = "8760h"
      extra_data = {
        addr = "https://vault.munchbox.cc:8200"
      }
    }
  }
}
