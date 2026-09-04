# -----------------------------------------------------------------------------
# cloudflare-zone-settings module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the flat zone_settings map fans out to one cloudflare_zone_setting per
# entry, DNSSEC fans out to one cloudflare_zone_dnssec per zone, and that empty
# inputs produce no resources.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  cloudflare_api_token = "mock-zonecfg-token"
  zone_settings = {
    "munchbox-ssl"             = { zone_id = "zone-mb", setting_id = "ssl", value = "strict" }
    "munchbox-min_tls_version" = { zone_id = "zone-mb", setting_id = "min_tls_version", value = "1.2" }
    "alexfreidah-ssl"          = { zone_id = "zone-af", setting_id = "ssl", value = "strict" }
  }
  zone_settings_numeric = {
    "munchbox-browser_cache_ttl" = { zone_id = "zone-mb", setting_id = "browser_cache_ttl", value = 0 }
  }
  # --- cloudflare_ruleset validates zone_id as 32-char hex, unlike
  #     zone_setting/zone_dnssec above which accept the short mock ids ---
  cache_rulesets = {
    munchbox = {
      zone_id = "0123456789abcdef0123456789abcdef"
      name    = "default"
      rules = [{
        description = "s3-orchestrator"
        expression  = "(http.request.full_uri contains \"s3-orchestrator.munchbox.cc\")"
        browser_ttl = { mode = "respect_origin" }
        edge_ttl    = { mode = "respect_origin" }
      }]
    }
  }
  dnssec_zones = {
    munchbox    = { zone_id = "zone-mb" }
    alexfreidah = { zone_id = "zone-af", multi_signer = true }
  }
}

# -------------------------------------------------------------------------
# zone_settings + dnssec maps fan out one resource per entry
# -------------------------------------------------------------------------

run "fan_out_per_entry" {
  command = plan

  # --- one cloudflare_zone_setting per zone_settings entry ---
  assert {
    condition     = length(cloudflare_zone_setting.this) == 3
    error_message = "three zone_settings entries -> three cloudflare_zone_setting resources"
  }

  # --- setting_id passes through to the resource ---
  assert {
    condition     = cloudflare_zone_setting.this["munchbox-ssl"].setting_id == "ssl"
    error_message = "munchbox-ssl entry must set setting_id ssl"
  }

  # --- numeric settings fan out on their own resource ---
  assert {
    condition     = length(cloudflare_zone_setting.numeric) == 1
    error_message = "one zone_settings_numeric entry -> one cloudflare_zone_setting"
  }

  # --- 0 stays a number; a quoted integer is rejected by the API ---
  assert {
    condition     = cloudflare_zone_setting.numeric["munchbox-browser_cache_ttl"].value == 0
    error_message = "browser_cache_ttl must pass through as numeric 0"
  }

  # --- cache ruleset lands on the cache phase with the right action ---
  assert {
    condition     = cloudflare_ruleset.cache["munchbox"].phase == "http_request_cache_settings"
    error_message = "cache rulesets must use the http_request_cache_settings phase"
  }

  # --- respect_origin, so nginx's per-content-type headers survive ---
  assert {
    condition = alltrue([
      cloudflare_ruleset.cache["munchbox"].rules[0].action == "set_cache_settings",
      cloudflare_ruleset.cache["munchbox"].rules[0].action_parameters.browser_ttl.mode == "respect_origin",
      cloudflare_ruleset.cache["munchbox"].rules[0].action_parameters.edge_ttl.mode == "respect_origin",
    ])
    error_message = "cache rule must set_cache_settings with both TTL modes respect_origin"
  }

  # --- one cloudflare_zone_dnssec per zone ---
  assert {
    condition     = length(cloudflare_zone_dnssec.this) == 2
    error_message = "two dnssec zones -> two cloudflare_zone_dnssec resources"
  }

  # --- dnssec is set active ---
  assert {
    condition     = cloudflare_zone_dnssec.this["munchbox"].status == "active"
    error_message = "dnssec status must be active"
  }

  # --- dnssec_ds_records keyed by every dnssec zone (ds is a computed attribute) ---
  assert {
    condition     = toset(keys(output.dnssec_ds_records)) == toset(["munchbox", "alexfreidah"])
    error_message = "dnssec_ds_records must be keyed by every dnssec zone"
  }
}

# -------------------------------------------------------------------------
# empty inputs create no resources
# -------------------------------------------------------------------------

run "empty_inputs_no_resources" {
  command = plan

  variables {
    zone_settings         = {}
    zone_settings_numeric = {}
    cache_rulesets        = {}
    dnssec_zones          = {}
  }

  # --- no settings when the map is empty ---
  assert {
    condition     = length(cloudflare_zone_setting.this) == 0
    error_message = "empty zone_settings -> no cloudflare_zone_setting resources"
  }

  # --- same for the numeric map ---
  assert {
    condition     = length(cloudflare_zone_setting.numeric) == 0
    error_message = "empty zone_settings_numeric -> no cloudflare_zone_setting resources"
  }

  # --- no dnssec when the map is empty ---
  assert {
    condition     = length(cloudflare_zone_dnssec.this) == 0
    error_message = "empty dnssec_zone_ids -> no cloudflare_zone_dnssec resources"
  }
}
