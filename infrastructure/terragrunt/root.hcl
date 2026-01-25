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

  ssh_public_key = get_env("MUNCHBOX_SSH_PUBKEY", file("~/.ssh/id_ed25519.pub"))

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
  # PROXMOX VMS (On-Prem Cluster)
  # ---------------------------------------------------------------------------
  # These are managed via Ansible post-provision, no cloud-init bootstrap

  proxmox_vms = {
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

  # ---------------------------------------------------------------------------
  # CONSUL-ACLS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Consul ACL policies and tokens, stored in Vault KV

  consul_acls_inputs = {
    consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
    vault_mount            = "secret"
  }

  # ---------------------------------------------------------------------------
  # NOMAD-ACLS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Nomad ACL policies and tokens, stored in Vault KV

  nomad_acls_inputs = {
    nomad_bootstrap_token = get_env("NOMAD_TOKEN", "")
    vault_mount           = "secret"
    backup_consul_token   = get_env("BACKUP_CONSUL_TOKEN", "")
  }

  # ---------------------------------------------------------------------------
  # OAUTH2-PROXY-SECRETS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Google OAuth credentials for oauth2-proxy, stored in Vault KV

  oauth2_proxy_secrets_inputs = {
    vault_mount    = "secret"
    client_id      = get_env("OAUTH2_PROXY_CLIENT_ID", "")
    client_secret  = get_env("OAUTH2_PROXY_CLIENT_SECRET", "")
    cookie_secret  = get_env("OAUTH2_PROXY_COOKIE_SECRET", "")
    allowed_emails = ["alex.freidah@gmail.com", "afreidah@gmail.com", "hart.koko@gmail.com"]
  }

  # ---------------------------------------------------------------------------
  # VAULT-CONFIG MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Vault secrets engines, auth backends, and policies

  vault_config_inputs = {
    # Feature flags
    kv_enabled               = true
    consul_secrets_enabled   = true
    jwt_auth_enabled         = true
    database_secrets_enabled = false
    pki_roles_enabled        = true
    policies_enabled         = true

    # Consul secrets engine
    consul_bootstrap_token = get_env("CONSUL_HTTP_TOKEN", "")
    consul_address         = "http://192.168.68.61:8500"

    # JWT auth for Nomad workload identity
    nomad_jwks_url = "https://192.168.68.61:4646/.well-known/jwks.json"

    # PKI configuration
    traefik_allowed_domains = ["munchbox.cc"]
    postgres_allowed_domains = [
      "postgres-primary.service.consul",
      "postgres-replica.service.consul",
      "postgres.service.consul",
      "node.consul"
    ]

    # Workload secrets accessible via nomad-workloads policy
    workload_secrets = [
      "traefik",
      "grafana",
      "backup-worker",
      "prometheus",
      "prometheus-nomad",
      "nomad-ui",
      "hashiuisecret",
      "alertmanager",
      "redis-shared",
      "postgres-shared/root",
      "postgres-shared/replication",
      "nextcloud",
      "deluge",
      "pia",
      "mullvad",
      "cloudflared",
      "vaultwarden",
      "temporal",
      "trivy-dashboard",
      "forgejo",
      "forgejo-runner",
      "umami",
      "s3-proxy",
      "patroni",
      "oauth2-proxy",
      "traefik-log-dashboard",
      "maxmind"
    ]
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
  # DNS MODULE INPUTS
  # ---------------------------------------------------------------------------
  # Cloudflare DNS records, tunnel configuration, and rate limiting

  cloudflare_account_id     = "02e53aa2113dc76e57f9598af2f74939"
  cloudflare_alexfreidah_zone_id = "79e647e591f69cc27254bf4771464619"
  cloudflare_munchbox_zone_id    = "bd3f7236466255155ab59b9d21cd88fd"
  cloudflare_tunnel_id      = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7"
  cloudflare_tunnel_cname   = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7.cfargotunnel.com"

  dns_inputs = {
    dns_records = {
      "alexfreidah-apex" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "@"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "alexfreidah-www" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "www"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "alexfreidah-resume" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "resume"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "alexfreidah-resume-www" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "www.resume"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "alexfreidah-k3s-status" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "k3s-status"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "alexfreidah-analytics" = {
        zone_id = local.cloudflare_alexfreidah_zone_id
        name    = "analytics"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
      "munchbox-wildcard" = {
        zone_id = local.cloudflare_munchbox_zone_id
        name    = "*"
        content = local.cloudflare_tunnel_cname
        type    = "CNAME"
      }
    }

    rate_limiting_rulesets = {
      "munchbox-auth" = {
        zone_id     = local.cloudflare_munchbox_zone_id
        name        = "Munchbox Rate Limiting"
        description = "Rate limiting rules for munchbox.cc services"
        rules = [
          {
            action              = "block"
            expression          = "(http.request.uri.path contains \"/Users/AuthenticateByName\")"
            description         = "Rate limit authentication attempts"
            characteristics     = ["cf.colo.id", "ip.src"]
            period              = 10
            requests_per_period = 3
            mitigation_timeout  = 10
          }
        ]
      }
    }

    tunnel_config = {
      account_id = local.cloudflare_account_id
      tunnel_id  = local.cloudflare_tunnel_id
      ingress_rules = [
        {
          hostname       = "alexfreidah.com"
          service        = "http://127.0.0.1:80"
          origin_request = { http_host_header = "alexfreidah.com" }
        },
        {
          hostname       = "www.alexfreidah.com"
          service        = "http://127.0.0.1:80"
          origin_request = { http_host_header = "www.alexfreidah.com" }
        },
        {
          hostname       = "resume.alexfreidah.com"
          service        = "http://127.0.0.1:80"
          origin_request = { http_host_header = "resume.alexfreidah.com" }
        },
        {
          hostname       = "k3s-status.alexfreidah.com"
          service        = "http://127.0.0.1:80"
          origin_request = { http_host_header = "k3s-status.alexfreidah.com" }
        },
        {
          hostname       = "analytics.alexfreidah.com"
          service        = "http://127.0.0.1:80"
          origin_request = { http_host_header = "analytics.alexfreidah.com" }
        },
        {
          hostname = "*.munchbox.cc"
          service  = "http://127.0.0.1:80"
        },
        {
          service = "http_status:404"
        }
      ]
    }
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
        uri            = "https://green.munchbox.cc/admin"
        vault_path     = "pihole/green"
        password_field = "password"
        folder_key     = "admin"
      }
      pihole_logan = {
        name           = "Pi-hole (logan)"
        uri            = "https://logan.munchbox.cc/admin"
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

    # Software versions
    consul_version = "1.17.0"
    nomad_version  = "1.7.0"

    # Docker
    allow_privileged_docker = false
    docker_user             = "ubuntu"

    tags = {
      Project   = "munchbox"
      ManagedBy = "terragrunt"
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
      }
    }

    provider "aws" {
      region = "us-east-1"

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
  EOF
}
