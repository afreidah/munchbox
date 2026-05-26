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
  # OAUTH2-PROXY  (composition lives in _env_helpers/oauth2-proxy-secrets.hcl)
  # ---------------------------------------------------------------------------

  # --- SSO-allowed emails ---
  oauth2_proxy_allowed_emails = [
    "alex.freidah@gmail.com",
    "afreidah@gmail.com",
    "hart.koko@gmail.com",
  ]

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
  # BLOCK-VOLUME-OCI  (composition lives in _env_helpers/block-volume-oci.hcl)
  # ---------------------------------------------------------------------------
  # --- keyed by terragrunt dir name; env_helper looks up by basename ---

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

  # --- trivy on rendered .tf source; hard-fail (--exit-code 1) on any misconfig ---
  after_hook "trivy_scan" {
    commands     = ["plan"]
    execute      = ["bash", "-c", "echo '== trivy =='; trivy config --exit-code 1 ."]
    run_on_error = false
  }

  # --- checkov on the same .tf source; hard-fail on any non-skipped finding ---
  after_hook "checkov_scan" {
    commands     = ["plan"]
    execute      = ["bash", "-c", "echo '== checkov =='; checkov -d . --framework terraform"]
    run_on_error = false
  }
}

# -----------------------------------------------------------------------------
# SCAN-TOOL CONFIG FILES (generated into every leaf so trivy/checkov see them)
# -----------------------------------------------------------------------------

generate "checkov_config" {
  path      = ".checkov.yaml"
  if_exists = "overwrite"
  contents  = <<-EOF
    # --- per-leaf checkov config (regenerated by terragrunt; edit in root.hcl) ---
    skip-check:
      # --- checkov 3.2.471 bugs: looks in wrong HCL location for these OCI checks ---
      - CKV_OCI_19
      - CKV_OCI_20
      - CKV_OCI_4
      # --- intentional: cloud nodes need public IPs ---
      - CKV_AWS_130
      # --- intentional: bootstrap SSH access, gated by var.allow_ssh when unused ---
      - CKV_AWS_24
      # --- intentional: ICMP for ping, gated by var.allow_icmp when unused ---
      - CKV_AWS_277
      # --- homelab: VPC flow logs not paying for ---
      - CKV2_AWS_11
      # --- false positive: module SG is attached by caller via output reference ---
      - CKV2_AWS_5
      # --- default SG is AWS-managed; cannot restrict from module here ---
      - CKV2_AWS_12
      # --- homelab: no OCI KMS keys for block-volume + object-storage CMK encryption ---
      - CKV_OCI_3
      - CKV_OCI_9
      # --- homelab: paying for OCI backup policies not worth it ---
      - CKV_OCI_2
      # --- homelab: object event streams + versioning not needed for backup bucket ---
      - CKV_OCI_7
      - CKV_OCI_8
  EOF
}

generate "trivy_ignore" {
  path      = ".trivyignore"
  if_exists = "overwrite"
  contents  = <<-EOF
    # --- per-leaf trivyignore (regenerated by terragrunt; edit in root.hcl) ---
  EOF
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
      required_version = ">= 1.5"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
        oci = {
          source  = "oracle/oci"
          version = "~> 8.0"
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
          version = "~> 5.0"
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
          version = "~> 5.0"
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
          version = "~> 2.0"
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
