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
  cloudflare_api_token  = data.vault_kv_secret_v2.dns.data["cloudflare_api_token"]
  cloudflare_zone_id    = data.vault_kv_secret_v2.dns.data["cloudflare_zone_id"]
  cloudflare_account_id = data.vault_kv_secret_v2.dns.data["cloudflare_account_id"]
  tunnel_cname          = data.vault_kv_secret_v2.dns.data["tunnel_cname"]
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

# -------------------------------------------------------------------------
# Cloudflare Tunnel Configuration
# -------------------------------------------------------------------------

resource "cloudflare_tunnel_config" "munchbox" {
  account_id = local.cloudflare_account_id
  tunnel_id  = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7"

  config {
    ingress_rule {
      hostname = "alexfreidah.com"
      service  = "http://traefik.service.consul:80"
      origin_request {
        http_host_header = "alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "www.alexfreidah.com"
      service  = "http://traefik.service.consul:80"
      origin_request {
        http_host_header = "www.alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "resume.alexfreidah.com"
      service  = "http://traefik.service.consul:80"
      origin_request {
        http_host_header = "resume.alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "k3s-status.alexfreidah.com"
      service  = "http://traefik.service.consul:80"
      origin_request {
        http_host_header = "k3s-status.alexfreidah.com"
      }
    }

    # Required catch-all rule
    ingress_rule {
      service = "http_status:404"
    }
  }
}
