# -----------------------------------------------------------------------------
# MUNCHBOX TERRAGRUNT ROOT CONFIGURATION
# -----------------------------------------------------------------------------
#
# Centralized configuration for all Munchbox infrastructure deployments.
# Environment-specific terragrunt.hcl files include this + their env_helper.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  # ---------------------------------------------------------------------------
  # PATH PARSING
  # ---------------------------------------------------------------------------
  # Parse the directory structure to determine provider and node name
  # Expected structure: terragrunt/<provider>/<node_name>/terragrunt.hcl

  # get_original_terragrunt_dir() returns the dir of the file that initiated the include
  terragrunt_dir = get_original_terragrunt_dir()
  node_name      = basename(local.terragrunt_dir)
  provider_type  = basename(dirname(local.terragrunt_dir))

  # ---------------------------------------------------------------------------
  # ENVIRONMENT CONFIG
  # ---------------------------------------------------------------------------
  # Load provider-specific configuration if it exists

  env_config_path = "${get_terragrunt_dir()}/../env.yaml"
  env_config      = fileexists(local.env_config_path) ? yamldecode(file(local.env_config_path)) : {}

  # Global defaults
  default_datacenter = "dc1"
  default_node_class = "cloud"

  # ---------------------------------------------------------------------------
  # WIREGUARD CONFIGURATION
  # ---------------------------------------------------------------------------
  # These should be overridden per-node or via environment variables

  wireguard_subnet            = "10.200.0.0/24"
  wireguard_server_public_key = get_env("MUNCHBOX_WG_SERVER_PUBKEY", "")
  wireguard_endpoint          = get_env("MUNCHBOX_WG_ENDPOINT", "home.example.com:51820")

  # ---------------------------------------------------------------------------
  # CLUSTER CONFIGURATION
  # ---------------------------------------------------------------------------

  consul_servers = ["10.200.0.1"]
  nomad_servers  = ["10.200.0.1:4647"]

  # ---------------------------------------------------------------------------
  # NETWORK CIDRS (Munchbox Convention)
  # ---------------------------------------------------------------------------

  network_cidrs = {
    homelab   = "192.168.68.0/24"
    wireguard = "10.200.0.0/24"
    oci       = "10.100.0.0/16"
    aws       = "10.101.0.0/16"
  }

  # ---------------------------------------------------------------------------
  # SSH CONFIGURATION
  # ---------------------------------------------------------------------------

  # --- Cloud-init seed key: workstation ed25519 only. Cluster-side SSH
  #     (stabler → oracle, break-glass keys, etc.) is managed by the
  #     sshd_ca recipe at converge time, not via cloud-init metadata. ---
  ssh_public_key = get_env("MUNCHBOX_SSH_PUBKEY", fileexists("~/.ssh/id_ed25519.pub") ? trimspace(file("~/.ssh/id_ed25519.pub")) : "")

  # ---------------------------------------------------------------------------
  # PROVIDER-SPECIFIC DEFAULTS
  # ---------------------------------------------------------------------------

  aws_defaults = {
    availability_zones = ["us-east-1a"]
    architecture       = "arm64"
    spot_type          = "persistent"
  }

  oci_defaults = {
    compartment_id = get_env("OCI_COMPARTMENT_ID", "")
  }

  proxmox_defaults = {
    target_node    = "pve"
    disk_storage   = "local-lvm"
    network_bridge = "vmbr0"
    template_name  = "debian-base"
  }

  # ---------------------------------------------------------------------------
  # PROXMOX VM GROUPS
  # ---------------------------------------------------------------------------
  # Keyed by terragrunt subdir name under terragrunt/proxmox/. The
  # _env_helpers/proxmox-cluster.hcl helper looks up the group via
  # basename(get_terragrunt_dir()), so a directory named `cluster` reads
  # `proxmox_vm_groups.cluster`, `cinc-server` reads
  # `proxmox_vm_groups.cinc-server`, etc.

  proxmox_vm_groups = {
    # The main Nomad/Consul/Vault cluster. Existing VMs are managed via
    # Ansible post-provision; cloud-init only set for the few that need it.
    cluster = {
      "nomad-server-03" = {
        target_node = "fontana"
        vmid        = 172
        memory      = 2048
        cores       = 2
        disk_size   = "40G"
        existing    = true
      }

      "nomad-client-01" = {
        target_node = "fontana"
        vmid        = 180
        memory      = 13312
        cores       = 4
        disk_size   = "60G"
        existing    = true
      }

      "nomad-client-02" = {
        target_node = "mccoy"
        vmid        = 181
        memory      = 15360
        cores       = 4
        disk_size   = "40G"
        existing    = true
      }

      "nomad-client-03" = {
        target_node = "cabot"
        vmid        = 182
        memory      = 7168
        cores       = 4
        disk_size   = "40G"
        existing    = true
      }

      "nomad-client-04" = {
        target_node     = "rubirosa"
        vmid            = 183
        memory          = 28672
        cores           = 10
        disk_size       = "140G"
        gpu_passthrough = { pci_address = "0000:02:00.0" }
        cloud_init = {
          ip         = "192.168.68.73/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
        }
      }

      "nomad-client-05" = {
        target_node = "rubirosa"
        vmid        = 184
        memory      = 28672
        cores       = 10
        disk_size   = "40G"
        cloud_init = {
          ip         = "192.168.68.74/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
        }
      }
    }

    # Cinc/Chef server host. Provisioned as its own group so it can be
    # applied independently of the cluster.
    cinc-server = {
      "cinc-server" = {
        target_node = "rubirosa"
        vmid        = 185
        memory      = 4096
        cores       = 2
        disk_size   = "60G"
        cloud_init = {
          ip         = "192.168.68.99/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
          sshkeys    = local.ssh_public_key
          # Attach a cloud-init CD-ROM so the OS can actually read the
          # ipconfig0 / ciuser settings above.
          storage = "local-lvm"
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # PROXMOX USERS & ROLES
  # ---------------------------------------------------------------------------
  # Service accounts for monitoring, backups, etc.

  proxmox_roles = {
    "prometheus-exporter" = {
      privileges = [
        "Sys.Audit",
        "SDN.Audit",
        "Datastore.Audit",
        "Pool.Audit",
        "VM.Audit",
      ]
    }
  }

  proxmox_users = {
    "prometheus" = {
      user_id = "prometheus@pve"
      comment = "PVE Exporter service account"
      # Password managed manually (API tokens can't change passwords)
      # Password stored in Vault at secret/proxmox for pve-exporter
      acls = [
        {
          path    = "/"
          role_id = "prometheus-exporter"
        }
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # CONSUL-ACLS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Consul ACL policies, tokens, and Vault secret storage configuration

  consul_acls_inputs = {
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

  # ---------------------------------------------------------------------------
  # NOMAD-ACLS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Nomad ACL policies, tokens, and Vault secret storage configuration

  nomad_acls_inputs = {
    nomad_bootstrap_token = get_env("NOMAD_TOKEN", "")
    vault_mount           = "secret"

    # --- ACL Policies ---
    policies = {
      # Operator Policies (no tokens generated - for human access via UI)
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

      # Service Policies (tokens generated for automated services)
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

    # --- ACL Tokens (only for services, not operators) ---
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

  # ---------------------------------------------------------------------------
  # NOMAD-CONFIG MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Cluster-level Nomad scheduler and node pool configuration

  nomad_config_inputs = {
    scheduler_algorithm             = "spread"
    memory_oversubscription_enabled = false

    preemption_config = {
      batch    = false
      service  = false
      sysbatch = false
      system   = true
    }

    # Only the "oracle" pool is managed here. On-prem nodes use the built-in
    # "default" pool. Workload placement within pools is handled by meta tag
    # constraints in job specs:
    #
    #   meta.role  = "ingress"   → goren, nomad-client-05
    #   meta.gpu   = "true"      → nomad-client-04
    #   meta.arch  = "arm64"     → oraclearm1, oraclearm2
    #   meta.arch  = "amd64"     → all other nodes
    #   meta.tier  = "micro"     → oraclenode1, oraclenode2
    node_pools = {
      "oracle" = {
        description = "Oracle Cloud nodes connected via WireGuard tunnel for remote/edge workloads"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # OAUTH2-PROXY  (composition lives in _env_helpers/oauth2-proxy-secrets.hcl)
  # ---------------------------------------------------------------------------

  # --- SSO-allowed emails ---
  oauth2_proxy_allowed_emails = [
    "alex.freidah@gmail.com",
    "afreidah@gmail.com",
    "hart.koko@gmail.com",
  ]

  # ---------------------------------------------------------------------------
  # VAULT-CONFIG MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Vault secrets engines, auth backends, policies, PKI roles, and database roles

  vault_config_inputs = {
    # Feature flags
    kv_enabled               = true
    consul_secrets_enabled   = true
    jwt_auth_enabled         = true
    database_secrets_enabled = false
    pki_roles_enabled        = true
    policies_enabled         = true
    transit_enabled          = true
    ssh_ca_enabled           = true

    # Consul secrets engine
    consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
    consul_address         = "http://192.168.68.61:8500"

    # JWT auth for Nomad workload identity
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
      "nextcloud",
      "deluge",
      "pia",
      "mullvad",
      "cloudflared",
      "cloudflare",
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
      "wireguard"
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

  # ---------------------------------------------------------------------------
  # KMS-OCI MODULE INPUTS
  # ---------------------------------------------------------------------------
  # OCI KMS vault and key for HashiCorp Vault auto-unseal

  kms_oci_inputs = {
    compartment_id     = local.oci_defaults.compartment_id
    vault_display_name = "munchbox-vault-unseal"
    vault_type         = "DEFAULT"
    key_display_name   = "vault-auto-unseal-key"
    protection_mode    = "SOFTWARE"

    tags = {
      Project   = "munchbox"
      ManagedBy = "terragrunt"
      Purpose   = "vault-auto-unseal"
    }
  }

  # ---------------------------------------------------------------------------
  # DNS  (composition lives in _env_helpers/dns.hcl)
  # ---------------------------------------------------------------------------

  cloudflare_account_id          = "02e53aa2113dc76e57f9598af2f74939"
  cloudflare_alexfreidah_zone_id = "79e647e591f69cc27254bf4771464619"
  cloudflare_munchbox_zone_id    = "bd3f7236466255155ab59b9d21cd88fd"
  cloudflare_tunnel_id           = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7"
  cloudflare_tunnel_cname        = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7.cfargotunnel.com"

  # --- alexfreidah-zone CNAMEs to the tunnel; map key = TF state key ---
  alexfreidah_tunnel_cnames = {
    "alexfreidah-apex"       = "@"
    "alexfreidah-www"        = "www"
    "alexfreidah-resume"     = "resume"
    "alexfreidah-resume-www" = "www.resume"
    "alexfreidah-k3s-status" = "k3s-status"
    "alexfreidah-analytics"  = "analytics"
  }

  # --- munchbox-zone records; wg = non-proxied A, kept current by oracle-watchdog ---
  munchbox_zone_records = {
    "munchbox-wildcard" = {
      name    = "*"
      type    = "CNAME"
      content = local.cloudflare_tunnel_cname
    }
    "munchbox-wg" = {
      name    = "wg"
      type    = "A"
      content = "23.240.245.39"
      proxied = false
      ttl     = 60
    }
  }

  # ---------------------------------------------------------------------------
  # CLOUDFLARE R2 MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Cloudflare R2 object storage bucket configuration

  cloudflare_r2_inputs = {
    account_id  = local.cloudflare_account_id
    bucket_name = "munchbox-backups"
  }

  # ---------------------------------------------------------------------------
  # PI-HOLE DNS  (composition lives in _env_helpers/pihole-dns.hcl)
  # ---------------------------------------------------------------------------
  # Local DNS records for split-horizon DNS: internal traffic skips the
  # cloudflare tunnel and lands directly on traefik (or, for the handful
  # of non-traefik records, wherever the host actually lives).

  pihole_primary_url   = "http://192.168.68.62"  # green
  pihole_secondary_url = "http://192.168.68.64"  # logan
  traefik_vip          = "192.168.68.50"

  # Hosts whose <name>.munchbox.cc A-record points at the traefik VIP.
  # env_helper expands each entry into { domain = "<name>.munchbox.cc", ip = traefik_vip }.
  traefik_fronted_hosts = [
    "alertmanager", "analytics", "apt", "auth", "consul", "dashboard",
    "deluge", "ersatz", "git", "grafana", "jellyfin", "kavita", "lidarr",
    "nextcloud", "nomad", "photos", "prometheus", "prowlarr", "radarr",
    "readarr", "registry", "registry-ui", "sonarr", "temporal", "themes",
    "traefik", "traefik-logs", "trivy-dashboard", "vault", "vault-ui",
    "vaultwarden", "pihole", "pihole-green", "pihole-logan", "s3", "forgejo",
  ]

  # Records that point somewhere other than the traefik VIP (cinc-server API
  # isn't fronted by traefik; clients hit the VM directly).
  pihole_special_dns_records = {
    "cinc-server" = { domain = "cinc-server.munchbox.cc", ip = "192.168.68.99" }
  }

  # ---------------------------------------------------------------------------
  # VAULTWARDEN-SECRETS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Syncs credentials from Vault to Vaultwarden for human access

  vaultwarden_secrets_inputs = {
    vault_mount = "secret"

    folders = {
      admin  = "Admin Services"
      shared = "Shared"
    }

    login_items = {
      nextcloud = {
        name           = "Nextcloud Admin"
        uri            = "https://nextcloud.munchbox.cc"
        vault_path     = "nextcloud"
        password_field = "admin_password"
        folder_key     = "admin"
      }
      grafana = {
        name           = "Grafana Admin"
        uri            = "https://grafana.munchbox.cc"
        vault_path     = "grafana"
        username_field = "admin_user"
        password_field = "admin_password"
        folder_key     = "admin"
      }
      pihole_green = {
        name           = "Pi-hole (green)"
        uri            = "https://pihole-green.munchbox.cc/admin"
        vault_path     = "pihole/green"
        password_field = "password"
        folder_key     = "admin"
      }
      pihole_logan = {
        name           = "Pi-hole (logan)"
        uri            = "https://pihole-logan.munchbox.cc/admin"
        vault_path     = "pihole/logan"
        password_field = "password"
        folder_key     = "admin"
      }
      deluge = {
        name           = "Deluge"
        uri            = "https://deluge.munchbox.cc"
        vault_path     = "deluge"
        password_field = "web_password"
        folder_key     = "shared"
        notes          = "Synced from HashiCorp Vault - Shared with family"
      }
      aptly = {
        name           = "Aptly Package Repo"
        uri            = "https://apt.munchbox.cc/ui/"
        vault_path     = "aptly"
        username       = "admin"
        password_field = "password"
        folder_key     = "admin"
      }
    }

    secure_note_items = {
      break_glass = {
        name          = "SSH Break-Glass Key"
        vault_path    = "ssh/break-glass"
        content_field = "private_key"
        folder_key    = "admin"
        notes         = "Emergency SSH access to all cluster nodes when Vault/certs are unavailable. Save to file (chmod 600), then: ssh -i /path/to/key root@<node>"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # FORGEJO-SECRETS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Syncs secrets from Vault to Forgejo for CI/CD pipelines

  forgejo_secrets_inputs = {
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

  # ---------------------------------------------------------------------------
  # BOOTSTRAP MODULE INPUTS
  # ---------------------------------------------------------------------------
  # These get merged with node-specific config in the env_helper

  bootstrap_inputs = {
    datacenter     = local.default_datacenter
    node_class     = local.default_node_class
    ssh_public_key = local.ssh_public_key

    wireguard_subnet            = local.wireguard_subnet
    wireguard_server_public_key = local.wireguard_server_public_key
    wireguard_endpoint          = local.wireguard_endpoint
    wireguard_allowed_ips       = "${local.network_cidrs.wireguard}, ${local.network_cidrs.homelab}"

    consul_servers = local.consul_servers
    nomad_servers  = local.nomad_servers

    # Software versions (legacy direct-install path; chef cookbooks pin separately).
    consul_version = "1.17.0"
    nomad_version  = "1.7.0"

    # Docker (legacy direct-install path).
    allow_privileged_docker = false
    docker_user             = "ubuntu"

    # --- Chef bootstrap (cloud-init path; the cookbooks take over after first converge) ---
    # The bootstrap module reads chef_validator + encrypted_data_bag_secret from Vault at
    # apply time via vault_kv_secret_v2 data sources. Per-node values (chef_node_name,
    # chef_run_list, bootstrap_wireguard, static_ip, etc.) are set in the env_helper.
    chef_server_url            = "https://cinc-server.munchbox.cc/organizations/munchbox"
    chef_validator_client_name = "munchbox-validator"
    cinc_version               = "19.2.12"

    chef_validator_vault_mount       = "secret"
    chef_validator_vault_name        = "cinc/validator"
    chef_validator_vault_field       = "pem"
    chef_data_bag_secret_vault_mount = "secret"
    chef_data_bag_secret_vault_name  = "cinc/encrypted_data_bag_secret"
    chef_data_bag_secret_vault_field = "value"

    hosts_overrides = {
      "cinc-server.munchbox.cc" = "192.168.68.99"
    }

    tags = {
      Project   = "munchbox"
      ManagedBy = "terragrunt"
    }
  }

  # ---------------------------------------------------------------------------
  # BLOCK-VOLUME-OCI MODULE INPUTS
  # ---------------------------------------------------------------------------
  # OCI block volumes attached to existing instances. Keyed by the terragrunt
  # directory name (e.g. "minio-volume") so the env_helper can look up config
  # from the directory path automatically.

  block_volume_oci_configs = {
    "minio-volume-1" = {
      target_node = "oracle-arm-1"
      purpose     = "minio-storage"
      volumes = [
        {
          name        = "minio-data"
          size_gb     = 80
          vpus_per_gb = 10
        }
      ]
    }
    "minio-volume-2" = {
      target_node = "oracle-arm-2"
      purpose     = "minio-storage"
      volumes = [
        {
          name        = "minio-data"
          size_gb     = 80
          vpus_per_gb = 10
        }
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# TERRAFORM CONFIGURATION
# -----------------------------------------------------------------------------

terraform_binary = "terraform"

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}

# -----------------------------------------------------------------------------
# REMOTE STATE
# -----------------------------------------------------------------------------

remote_state {
  backend = "consul"

  config = {
    address = "consul.service.consul:8500"
    scheme  = "http"
    path    = "terraform/munchbox/${local.provider_type}/${local.node_name}"
    lock    = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# PROVIDER GENERATION
# -----------------------------------------------------------------------------

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
        oci = {
          source  = "oracle/oci"
          version = "~> 5.0"
        }
        proxmox = {
          source  = "telmate/proxmox"
          version = "3.0.2-rc07"
        }
        consul = {
          source  = "hashicorp/consul"
          version = "~> 2.20"
        }
        vault = {
          source  = "hashicorp/vault"
          version = "~> 3.25"
        }
        nomad = {
          source  = "hashicorp/nomad"
          version = "~> 2.1"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 4.0"
        }
        bitwarden = {
          source  = "maxlaverse/bitwarden"
          version = "~> 0.12"
        }
        forgejo = {
          source  = "svalabs/forgejo"
          version = "~> 1.1"
        }
        pihole = {
          source  = "ryanwholey/pihole"
          version = "~> 0.2"
        }
        ibm = {
          source  = "IBM-Cloud/ibm"
          version = "~> 1.89"
        }
      }
    }

    provider "aws" {
      region = "us-east-1"

      skip_credentials_validation = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_region_validation      = true

      default_tags {
        tags = {
          Project   = "munchbox"
          ManagedBy = "terragrunt"
        }
      }
    }

    provider "oci" {
      # Uses OCI config file (~/.oci/config) or environment variables
    }

    provider "proxmox" {
      # Uses PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET env vars
      pm_tls_insecure = true
    }

    provider "consul" {
      # Uses CONSUL_HTTP_ADDR and CONSUL_HTTP_TOKEN env vars
    }

    provider "vault" {
      # Uses VAULT_ADDR and VAULT_TOKEN env vars
    }

    provider "nomad" {
      # Uses NOMAD_ADDR and NOMAD_TOKEN env vars
    }

    provider "random" {
      # No configuration needed
    }

    provider "cloudflare" {
      # Uses CLOUDFLARE_API_TOKEN env var
    }

    provider "bitwarden" {
      server          = "https://vaultwarden.munchbox.cc"
      email           = "alex.freidah@gmail.com"
      master_password = "${get_env("VAULTWARDEN_MASTER_PASSWORD", "")}"
    }

    provider "forgejo" {
      # --- Default points at the in-cluster consul-DNS name (works when terragrunt
      #     runs on cinc-server / stabler / any consul-DNS-resolving node). Operators
      #     running off-cluster set FORGEJO_HOST to a reachable URL (SSH-tunnel to
      #     cinc-server's port 30028, public bypass route, etc.).
      host      = "${get_env("FORGEJO_HOST", "http://forgejo.service.consul:30028")}"
      api_token = "${get_env("FORGEJO_API_TOKEN", "")}"
    }

    provider "pihole" {
      alias    = "primary"
      url      = "http://192.168.68.62"
      password = "${get_env("TF_VAR_pihole_password_primary", "")}"
    }

    provider "pihole" {
      alias    = "secondary"
      url      = "http://192.168.68.64"
      password = "${get_env("TF_VAR_pihole_password_secondary", "")}"
    }

    provider "ibm" {
      # --- ibmcloud_api_key wired explicitly: the env-var fallback isn't honored
      #     by every sub-service client in the provider (resource-manager in
      #     particular skips it and errors with "BearerToken property is required"
      #     at read time). IC_API_KEY itself is populated by munchbox-env.sh from
      #     vault: secret/ibm-cloud. ---
      ibmcloud_api_key = "${get_env("IC_API_KEY", "")}"
      region           = "${get_env("IBM_REGION", "us-south")}"
    }
  EOF
}
