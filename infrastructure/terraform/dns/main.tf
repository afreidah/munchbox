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
  address      = "https://192.168.68.61:8200"
  ca_cert_file = pathexpand("~/.munchbox/ca-chain.crt")
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
  munchbox_zone_id      = data.vault_kv_secret_v2.dns.data["munchbox_zone_id"]
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

# --- analytics.alexfreidah.com ---
resource "cloudflare_record" "analytics" {
  zone_id = local.cloudflare_zone_id
  name    = "analytics"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------------
# Cloudflare - munchbox.cc DNS Records (Wildcard)
# -------------------------------------------------------------------------
# Wildcard record routes all *.munchbox.cc subdomains through the tunnel.
# Services control their own routing via Traefik tags in their Nomad jobs.
# No per-service DNS changes needed - just add traefik tags to expose publicly.

resource "cloudflare_record" "munchbox_wildcard" {
  zone_id = local.munchbox_zone_id
  name    = "*"
  content = local.tunnel_cname
  type    = "CNAME"
  proxied = true
}

# -------------------------------------------------------------------------
# Cloudflare WAF Rate Limiting Rules (munchbox.cc)
# -------------------------------------------------------------------------
# Protects public API endpoints from brute force attacks.
# Blocks IPs that exceed request limits at Cloudflare edge.

resource "cloudflare_ruleset" "munchbox_rate_limiting" {
  zone_id     = local.munchbox_zone_id
  name        = "Munchbox Rate Limiting"
  description = "Rate limiting rules for munchbox.cc services"
  kind        = "zone"
  phase       = "http_ratelimit"

  # --- Authentication Rate Limiting (Free tier: 1 rule max) ---
  # Block IPs making too many auth requests (brute force protection)
  # Covers Emby auth endpoint - add more hosts with OR as needed
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"/Users/AuthenticateByName\")"
    description = "Rate limit authentication attempts"
    enabled     = true

    ratelimit {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = 3
      mitigation_timeout  = 10
    }
  }
}

# -------------------------------------------------------------------------
# Cloudflare Tunnel Configuration
# -------------------------------------------------------------------------

resource "cloudflare_tunnel_config" "munchbox" {
  account_id = local.cloudflare_account_id
  tunnel_id  = "7030f58c-6e0b-4161-8ae3-b7b96f56ffb7"

  config {
    # Routes to local Traefik (127.0.0.1) - each cloudflared routes to its co-located Traefik
    ingress_rule {
      hostname = "alexfreidah.com"
      service  = "http://127.0.0.1:80"
      origin_request {
        http_host_header = "alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "www.alexfreidah.com"
      service  = "http://127.0.0.1:80"
      origin_request {
        http_host_header = "www.alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "resume.alexfreidah.com"
      service  = "http://127.0.0.1:80"
      origin_request {
        http_host_header = "resume.alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "k3s-status.alexfreidah.com"
      service  = "http://127.0.0.1:80"
      origin_request {
        http_host_header = "k3s-status.alexfreidah.com"
      }
    }

    ingress_rule {
      hostname = "analytics.alexfreidah.com"
      service  = "http://127.0.0.1:80"
      origin_request {
        http_host_header = "analytics.alexfreidah.com"
      }
    }

    # --- munchbox.cc wildcard ---
    # All *.munchbox.cc subdomains route to local Traefik.
    # Traefik handles routing based on service tags registered in Consul.
    # To expose a new service: add traefik tags to its Nomad job - no Terraform changes needed.
    ingress_rule {
      hostname = "*.munchbox.cc"
      service  = "http://127.0.0.1:80"
    }

    # Required catch-all rule
    ingress_rule {
      service = "http_status:404"
    }
  }
}
