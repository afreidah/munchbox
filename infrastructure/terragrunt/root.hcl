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

  # get_original_terragrunt_dir() returns the dir of the file that initiated the include
  terragrunt_dir = get_original_terragrunt_dir()
  node_name      = basename(local.terragrunt_dir)
  provider_type  = basename(dirname(local.terragrunt_dir))

  # ---------------------------------------------------------------------------
  # ENVIRONMENT CONFIG
  # ---------------------------------------------------------------------------

  env_config_path = "${get_terragrunt_dir()}/../env.yaml"
  env_config      = fileexists(local.env_config_path) ? yamldecode(file(local.env_config_path)) : {}

  # Global defaults
  default_datacenter = "dc1"
  default_node_class = "cloud"

  # ---------------------------------------------------------------------------
  # WIREGUARD CONFIGURATION should be overridden per-node 
  # --------------------------------------------------------------------------- 

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

  # --- Cloud-init seed key: workstation ed25519 only. Cluster-side SSH is vault managed ---
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

    # --- Cinc server host. Provisioned as its own group so it can be applied independently of the cluster ---
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
  # PROXMOX USERS & ROLES - Service accounts for monitoring, backups, etc.
  # ---------------------------------------------------------------------------

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

  cloudflare_r2_inputs = {
    account_id  = local.cloudflare_account_id
    bucket_name = "munchbox-backups"
  }

  # ---------------------------------------------------------------------------
  # PI-HOLE DNS  (composition lives in _env_helpers/pihole-dns.hcl)
  # ---------------------------------------------------------------------------

  pihole_primary_url   = "http://192.168.68.62"  # green
  pihole_secondary_url = "http://192.168.68.64"  # logan
  traefik_vip          = "192.168.68.50"

  # --- SSH-reachable Pi-hole nodes for pihole/unbound ---
  pihole_nodes = [
    { name = "green", host = "192.168.68.62" },
    { name = "logan", host = "192.168.68.64" },
  ]

  # --- hosts that route to traefik VIP ---
  traefik_fronted_hosts = [
    "alertmanager", "analytics", "apt", "auth", "consul", "dashboard",
    "deluge", "ersatz", "git", "grafana", "jellyfin", "kavita", "lidarr",
    "nextcloud", "nomad", "photos", "prometheus", "prowlarr", "radarr",
    "readarr", "registry", "registry-ui", "sonarr", "temporal", "themes",
    "traefik", "traefik-logs", "trivy-dashboard", "vault", "vault-ui",
    "vaultwarden", "pihole", "s3", "forgejo",
  ]

  # --- hosts reached directly by ip ---
  pihole_special_dns_records = {
    "cinc-server"  = { domain = "cinc-server.munchbox.cc", ip = "192.168.68.99" }
    "pihole-green" = { domain = "pihole-green.munchbox.cc", ip = "192.168.68.62" }
    "pihole-logan" = { domain = "pihole-logan.munchbox.cc", ip = "192.168.68.64" }
  }

  # ---------------------------------------------------------------------------
  # REMOTE-FILES  (composition lives in _env_helpers/remote-files.hcl)
  # ---------------------------------------------------------------------------
  # --- keyed by leaf dir name (node_name). Each entry feeds the remote-files
  #     module: targets to ship to + bundles of files with a check/restart
  #     hook. File CONTENT is not in this map; each leaf owns a files/ dir
  #     and the env_helper loads bytes by file_key. ---

  remote_files_configs = {
    pihole-shared = {
      targets = local.pihole_nodes
      bundles = {
        unbound = {
          files = {
            "pi-hole.conf" = { destination = "/etc/unbound/unbound.conf.d/pi-hole.conf" }
          }
          # --- mkdir+chown: logfile dir missing pre-existing; checkconf fails without it ---
          check_command   = "mkdir -p /var/log/unbound && chown unbound:unbound /var/log/unbound && unbound-checkconf /etc/unbound/unbound.conf.d/pi-hole.conf"
          restart_command = "systemctl restart unbound && systemctl is-active --quiet unbound"
        }

        dnsmasq = {
          files = {
            "10-munchbox-vips.conf" = { destination = "/etc/dnsmasq.d/10-munchbox-vips.conf" }
            "munchbox-no-ipv6.conf" = { destination = "/etc/dnsmasq.d/munchbox-no-ipv6.conf" }
          }
          # --- reloaddns reloads dnsmasq.d w/o FTL restart (avoids the 30s outage window) ---
          check_command   = "pihole-FTL dnsmasq-test"
          restart_command = "pihole reloaddns"
        }

        node_exporter = {
          files = {
            "node_exporter.service" = { destination = "/etc/systemd/system/node_exporter.service" }
          }
          restart_command = "systemctl daemon-reload && systemctl enable --now node_exporter && systemctl is-active --quiet node_exporter"
        }

        consul_register = {
          files = {
            "consul-register.sh"      = { destination = "/usr/local/bin/consul-register.sh", mode = "0755" }
            "consul-register.service" = { destination = "/etc/systemd/system/consul-register.service" }
            "consul-register.timer"   = { destination = "/etc/systemd/system/consul-register.timer" }
          }
          # --- daemon-reload, enable timer, kick the one-shot once so JSON deltas land immediately ---
          restart_command = "systemctl daemon-reload && systemctl enable --now consul-register.timer && systemctl start consul-register.service"
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # BLOCK-VOLUME-OCI - keyed by terragrunt dir name
  # ---------------------------------------------------------------------------

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
