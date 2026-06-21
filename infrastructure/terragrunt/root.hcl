# -----------------------------------------------------------------------------
# MUNCHBOX TERRAGRUNT ROOT CONFIGURATION
# -----------------------------------------------------------------------------
#
# Centralized configuration for all Munchbox infrastructure deployments.
# Environment-specific terragrunt.hcl files include this + their env_helper.
#
# Holds only cross-cutting values read by 2+ env_helpers (path parsing, network,
# ssh, provider defaults, cloudflare/pihole shared ids). Component-specific
# catalogs (proxmox VMs, dns records, schedules, buckets, ...) live in that
# component's _env_helpers/<name>.hcl, not here.
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
  # --- VM leaves live at <provider>/vms/<node>; provider is the grandparent there, else the parent ---
  provider_type = basename(dirname(local.terragrunt_dir)) == "vms" ? basename(dirname(dirname(local.terragrunt_dir))) : basename(dirname(local.terragrunt_dir))

  # ---------------------------------------------------------------------------
  # ENVIRONMENT CONFIG
  # ---------------------------------------------------------------------------

  env_config_path = "${get_terragrunt_dir()}/../env.yaml"
  env_config      = fileexists(local.env_config_path) ? yamldecode(file(local.env_config_path)) : {}

  # ---------------------------------------------------------------------------
  # NETWORK (shared wg subnet + CIDR conventions; per-node wg + bootstrap seed
  # values live in _env_helpers/bootstrap.hcl)
  # ---------------------------------------------------------------------------

  wireguard_subnet = "10.200.0.0/24"


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
  # CLOUDFLARE  (shared zone/account ids; record + token maps live in the
  # dns / cloudflare-tokens / vault-secrets env_helpers)
  # ---------------------------------------------------------------------------

  cloudflare_account_id          = "02e53aa2113dc76e57f9598af2f74939"
  cloudflare_alexfreidah_zone_id = "79e647e591f69cc27254bf4771464619"
  cloudflare_munchbox_zone_id    = "bd3f7236466255155ab59b9d21cd88fd"
  cloudflare_tunnel_id           = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7"
  cloudflare_tunnel_cname        = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7.cfargotunnel.com"

  # ---------------------------------------------------------------------------
  # PI-HOLE  (shared provider URLs; record maps live in pihole-dns/pihole-config)
  # ---------------------------------------------------------------------------

  pihole_primary_url   = "http://192.168.68.62" # green
  pihole_secondary_url = "http://192.168.68.64" # logan

  # ---------------------------------------------------------------------------
  # WEB SERVICES CATALOG  (single source of truth for service DNS)
  #
  # munchbox.cc services get an internal Pi-hole A-record -> Traefik VIP, and a
  # proxied Cloudflare CNAME -> tunnel when public = true. alexfreidah.com sites
  # are public-only (zone = "alexfreidah", explicit hosts, CNAME -> tunnel, no
  # internal record). Deny-by-default: omit public and it's LAN-only.
  # Consumed by _env_helpers/pihole-dns.hcl (munchbox keys) and
  # _env_helpers/dns.hcl (public subset, both zones).
  # ---------------------------------------------------------------------------

  web_services = {
    # --- public (munchbox.cc) ---
    "auth"                     = { public = true }
    "jellyfin"                 = { public = true }
    "g3"                       = { public = true }
    "s3-orchestrator"          = { public = true }
    "cloudflare-log-collector" = { public = true }
    "nomad-temporal-jobs"      = { public = true }
    "oracle-watchdog"          = { public = true }
    "flights"                  = { public = true }

    # --- public (alexfreidah.com zone) ---
    "personal-site"  = { public = true, zone = "alexfreidah", hosts = ["@", "www"] }
    "nginx-resume"   = { public = true, zone = "alexfreidah", hosts = ["resume", "www.resume"] }
    "health-checker" = { public = true, zone = "alexfreidah", hosts = ["k3s-status"] }

    # --- internal only (munchbox.cc, LAN by name) ---
    "alertmanager"    = {}
    "apt"             = {}
    "consul"          = {}
    "dashboard"       = {}
    "deluge"          = {}
    "dns"             = {}
    "ersatz"          = {}
    "g3-proxy"        = {}
    "git"             = {}
    "gitgogit"        = {}
    "grafana"         = {}
    "haproxy"         = {}
    "lidarr"          = {}
    "nomad"           = {}
    "pihole"          = {}
    "pihole-green"    = {}
    "pihole-logan"    = {}
    "prometheus"      = {}
    "prowlarr"        = {}
    "proxmox"         = {}
    "radarr"          = {}
    "readarr"         = {}
    "registry"        = {}
    "registry-ui"     = {}
    "s3"              = {}
    "sonarr"          = {}
    "temporal"        = {}
    "themes"          = {}
    "traefik"         = {}
    "traefik-logs"    = {}
    "trivy-dashboard" = {}
    "vault"           = {}
    "vault-ui"        = {}
    "vaultwarden"     = {}
    "zfs"             = {}
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

  # --- checkov on the same .tf source; hard-fail on any non-skipped finding ---
  after_hook "checkov_scan" {
    commands     = ["plan"]
    execute      = ["bash", "-c", "echo '== checkov =='; checkov -d . --framework terraform"]
    run_on_error = false
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
    path    = "terraform/munchbox/${path_relative_to_include()}"
    lock    = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
