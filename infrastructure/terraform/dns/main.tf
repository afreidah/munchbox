# -------------------------------------------------------------------------------
# DNS Configuration - Cloudflare
#
# Project: Munchbox / Author: Alex Freidah
#
# Manages public DNS records via Cloudflare pointing to existing tunnel.
# Local DNS (*.munchbox.cc) handled via dnsmasq on Pi-hole.
# Secrets pulled from Vault at secret/dns.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/dns"
  }
}

# -------------------------------------------------------------------------
# Vault Provider & Secrets
# -------------------------------------------------------------------------

provider "vault" {
  address = "http://192.168.68.61:8200"
}

data "vault_kv_secret_v2" "dns" {
  mount = "secret"
  name  = "dns"
}

# -------------------------------------------------------------------------
# Local Variables
# -------------------------------------------------------------------------

locals {
  cloudflare_api_token = data.vault_kv_secret_v2.dns.data["cloudflare_api_token"]
  cloudflare_zone_id   = data.vault_kv_secret_v2.dns.data["cloudflare_zone_id"]
  tunnel_cname         = data.vault_kv_secret_v2.dns.data["tunnel_cname"]
}

# -------------------------------------------------------------------------
# Cloudflare Provider
# -------------------------------------------------------------------------

provider "cloudflare" {
  api_token = local.cloudflare_api_token
}

# -------------------------------------------------------------------------
# Cloudflare - DNS Records (pointing to existing tunnel)
# -------------------------------------------------------------------------

# --- resume.alexfreidah.com ---
resource "cloudflare_record" "resume" {
  zone_id = local.cloudflare_zone_id
  name    = "resume"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# --- www.resume.alexfreidah.com ---
resource "cloudflare_record" "resume_www" {
  zone_id = local.cloudflare_zone_id
  name    = "www.resume"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# --- k3s-status.alexfreidah.com ---
resource "cloudflare_record" "k3s_status" {
  zone_id = local.cloudflare_zone_id
  name    = "k3s-status"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# --- alexfreidah.com (apex) ---
resource "cloudflare_record" "apex" {
  zone_id = local.cloudflare_zone_id
  name    = "@"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# --- www.alexfreidah.com ---
resource "cloudflare_record" "www" {
  zone_id = local.cloudflare_zone_id
  name    = "www"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}
