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
    zone_settings = {}
    dnssec_zones  = {}
  }

  # --- no settings when the map is empty ---
  assert {
    condition     = length(cloudflare_zone_setting.this) == 0
    error_message = "empty zone_settings -> no cloudflare_zone_setting resources"
  }

  # --- no dnssec when the map is empty ---
  assert {
    condition     = length(cloudflare_zone_dnssec.this) == 0
    error_message = "empty dnssec_zone_ids -> no cloudflare_zone_dnssec resources"
  }
}
