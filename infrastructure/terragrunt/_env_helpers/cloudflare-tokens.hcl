# -----------------------------------------------------------------------------
# CLOUDFLARE TOKENS ENV HELPER
# -----------------------------------------------------------------------------
#
# Mints scoped Cloudflare API tokens from the cloudflare_token_requests map
# below (zone/account ids come from root.hcl). The module is Vault-free: token
# values are exposed as outputs and written to Vault by separate consumer leaves
# via terragrunt dependency.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//cloudflare-api-token"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))

  # --- scoped API tokens minted by modules/cloudflare-api-token (Vault-free) ---
  cloudflare_token_requests = {
    wandns = {
      name = "munchbox-wandns-dns-edit"
      policies = [{
        permission_groups = ["DNS Write"]
        resources         = { "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_munchbox_zone_id}" = "*" }
      }]
    }
    # --- cloudflare-log-collector: audit logs + per-zone analytics, read-only ---
    # Single policy on purpose: the cloudflare v5 provider can't round-trip a token with
    # multiple policies ("inconsistent result after apply"). One policy is fine even with
    # mixed scopes - each permission group only applies to its matching resource type:
    # Account Settings Read -> the account resource (audit logs); Analytics Read -> the
    # zone resources (per-zone GraphQL firewall/http analytics).
    logcollector = {
      name = "munchbox-logcollector-audit-analytics"
      policies = [{
        permission_groups = ["Analytics Read", "Account Settings Read"]
        resources = {
          "com.cloudflare.api.account.${local.root.locals.cloudflare_account_id}"               = "*"
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_munchbox_zone_id}"    = "*"
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_alexfreidah_zone_id}" = "*"
        }
      }]
    }
    # --- cloudflare-zone-settings leaf: provider creds for zone settings + dnssec ---
    zonecfg = {
      name = "munchbox-zone-settings-tls-dnssec"
      policies = [{
        permission_groups = ["Zone Settings Read", "Zone Settings Write", "DNS Read", "DNS Write"]
        resources = {
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_munchbox_zone_id}"    = "*"
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_alexfreidah_zone_id}" = "*"
        }
      }]
    }
    # --- dns leaf provider creds: DNS records (zones) + tunnel ingress (account) ---
    dnsedge = {
      name = "munchbox-dns-tunnel-edit"
      policies = [{
        permission_groups = ["DNS Read", "DNS Write", "Cloudflare Tunnel Read", "Cloudflare Tunnel Write"]
        resources = {
          "com.cloudflare.api.account.${local.root.locals.cloudflare_account_id}"               = "*"
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_munchbox_zone_id}"    = "*"
          "com.cloudflare.api.account.zone.${local.root.locals.cloudflare_alexfreidah_zone_id}" = "*"
        }
      }]
    }
  }
}

inputs = {
  tokens = local.cloudflare_token_requests
}
