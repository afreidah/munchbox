# -----------------------------------------------------------------------------
# dns module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the dns_records for_each fan-out, the proxied/ttl optional-field
# defaults (proxied=true, ttl=1) when not in the map entry, the conditional
# count gating on cloudflare_zero_trust_tunnel_cloudflared_config, and the
# ruleset rules-list comprehension expansion.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  cloudflare_api_token = "mock-dnsedge-token"
  dns_records = {
    "apex" = { zone_id = "0123456789abcdef0123456789abcdef", name = "@", content = "tunnel.example", type = "CNAME" }
    "www"  = { zone_id = "0123456789abcdef0123456789abcdef", name = "www", content = "tunnel.example", type = "CNAME" }
    "wg"   = { zone_id = "0123456789abcdef0123456789abcdef", name = "wg", content = "1.2.3.4", type = "A", proxied = false, ttl = 60 }
  }
}

# -------------------------------------------------------------------------
# dns_records for_each: one resource per map key
# -------------------------------------------------------------------------

run "dns_records_for_each" {
  command = plan

  # --- three dns_records inputs -> three resources ---
  assert {
    condition     = length(cloudflare_dns_record.records) == 3
    error_message = "three dns_records inputs -> three resources"
  }

  # --- apex record name propagates from map value ---
  assert {
    condition     = cloudflare_dns_record.records["apex"].name == "@"
    error_message = "apex record name should be @"
  }

  # --- records output keyed by every dns_records entry ---
  assert {
    condition     = toset(keys(output.records)) == toset(["apex", "www", "wg"])
    error_message = "records output must be keyed by every dns_records entry"
  }

  # --- records output surfaces hostname/type/proxied per entry ---
  assert {
    condition     = output.records["apex"].type == "CNAME"
    error_message = "records output must surface the record type"
  }

  assert {
    condition     = output.records["wg"].proxied == false
    error_message = "records output must surface proxied as configured"
  }
}

# -------------------------------------------------------------------------
# proxied: defaults to true when omitted; explicit false respected
# -------------------------------------------------------------------------

run "proxied_defaulting" {
  command = plan

  # --- apex omitted proxied -> default true ---
  assert {
    condition     = cloudflare_dns_record.records["apex"].proxied == true
    error_message = "proxied should default to true when omitted"
  }

  # --- wg explicit proxied=false respected ---
  assert {
    condition     = cloudflare_dns_record.records["wg"].proxied == false
    error_message = "explicit proxied = false should be respected"
  }
}

# -------------------------------------------------------------------------
# ttl: defaults to 1 when omitted; explicit value respected
# -------------------------------------------------------------------------

run "ttl_defaulting" {
  command = plan

  # --- apex omitted ttl -> default 1 ---
  assert {
    condition     = cloudflare_dns_record.records["apex"].ttl == 1
    error_message = "ttl should default to 1 when omitted"
  }

  # --- wg explicit ttl=60 respected ---
  assert {
    condition     = cloudflare_dns_record.records["wg"].ttl == 60
    error_message = "explicit ttl = 60 should be respected"
  }
}

# -------------------------------------------------------------------------
# tunnel_config null -> no tunnel resource (count = 0)
# -------------------------------------------------------------------------

run "tunnel_skipped_when_null" {
  command = plan

  # --- tunnel resource count = 0 when tunnel_config is null ---
  assert {
    condition     = length(cloudflare_zero_trust_tunnel_cloudflared_config.tunnel) == 0
    error_message = "no tunnel resource when var.tunnel_config = null"
  }

  # --- tunnel_config_id output is null when no tunnel is configured ---
  assert {
    condition     = output.tunnel_config_id == null
    error_message = "tunnel_config_id must be null when tunnel_config is null"
  }
}

# -------------------------------------------------------------------------
# tunnel_config set -> tunnel resource created with ingress list
# -------------------------------------------------------------------------

run "tunnel_created_when_set" {
  command = plan

  variables {
    tunnel_config = {
      account_id = "acct-mock"
      tunnel_id  = "tun-mock"
      ingress_rules = [
        { hostname = "a.example.com", service = "http://127.0.0.1:80", origin_request = { http_host_header = "a.example.com" } },
        { service = "http_status:404" },
      ]
    }
  }

  # --- tunnel resource count = 1 when tunnel_config is set ---
  assert {
    condition     = length(cloudflare_zero_trust_tunnel_cloudflared_config.tunnel) == 1
    error_message = "tunnel resource should be created when tunnel_config is set"
  }

  # --- ingress list length mirrors input ingress_rules ---
  assert {
    condition     = length(cloudflare_zero_trust_tunnel_cloudflared_config.tunnel[0].config.ingress) == 2
    error_message = "ingress list should mirror input length"
  }

  # --- pin the computed tunnel id at plan time so the conditional
  #     tunnel_config_id output is assertable (computed attrs are
  #     otherwise unknown until apply) ---
  override_resource {
    target          = cloudflare_zero_trust_tunnel_cloudflared_config.tunnel[0]
    override_during = plan
    values = {
      id = "tun-cfg-mock"
    }
  }

  # --- tunnel_config_id output reflects the created tunnel's id ---
  assert {
    condition     = output.tunnel_config_id == "tun-cfg-mock"
    error_message = "tunnel_config_id must reflect the created tunnel id"
  }
}

# -------------------------------------------------------------------------
# Empty inputs edge case: zero records, zero rulesets
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    dns_records            = {}
    rate_limiting_rulesets = {}
  }

  # --- empty dns_records -> zero records ---
  assert {
    condition     = length(cloudflare_dns_record.records) == 0
    error_message = "empty dns_records -> zero records"
  }

  # --- empty rate_limiting_rulesets -> zero rulesets ---
  assert {
    condition     = length(cloudflare_ruleset.rate_limiting) == 0
    error_message = "empty rate_limiting_rulesets -> zero rulesets"
  }
}

# -------------------------------------------------------------------------
# Ruleset rules-list comprehension expansion
# -------------------------------------------------------------------------

run "ruleset_rules_expansion" {
  command = plan

  variables {
    dns_records = {}
    rate_limiting_rulesets = {
      "auth-limit" = {
        zone_id = "0123456789abcdef0123456789abcdef"
        name    = "auth-limit"
        rules = [
          {
            action              = "block"
            expression          = "true"
            characteristics     = ["ip.src"]
            period              = 10
            requests_per_period = 3
            mitigation_timeout  = 10
          },
        ]
      }
    }
  }

  # --- one ruleset input -> one ruleset resource ---
  assert {
    condition     = length(cloudflare_ruleset.rate_limiting) == 1
    error_message = "one ruleset input -> one ruleset resource"
  }

  # --- inner rules list length matches input ---
  assert {
    condition     = length(cloudflare_ruleset.rate_limiting["auth-limit"].rules) == 1
    error_message = "ruleset's rules list should have one entry"
  }
}
