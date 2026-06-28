# -----------------------------------------------------------------------------
# cloudflare-web-analytics module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the sites map fans out to one cloudflare_web_analytics_site per entry,
# that account_id and the install toggles pass through, and that empty inputs
# produce no resources.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  cloudflare_api_token = "mock-webanalytics-token"
  account_id           = "acct-mb"
  sites = {
    munchbox    = { zone_tag = "zone-mb", auto_install = true, enabled = true }
    alexfreidah = { zone_tag = "zone-af", auto_install = true, enabled = true }
  }
}

# -------------------------------------------------------------------------
# sites map fans out one resource per entry
# -------------------------------------------------------------------------

run "fan_out_per_site" {
  command = plan

  # --- one cloudflare_web_analytics_site per sites entry ---
  assert {
    condition     = length(cloudflare_web_analytics_site.this) == 2
    error_message = "two sites entries -> two cloudflare_web_analytics_site resources"
  }

  # --- account_id passes through to the resource ---
  assert {
    condition     = cloudflare_web_analytics_site.this["munchbox"].account_id == "acct-mb"
    error_message = "munchbox site must set account_id acct-mb"
  }

  # --- auto_install / enabled toggles pass through ---
  assert {
    condition     = cloudflare_web_analytics_site.this["munchbox"].auto_install == true
    error_message = "munchbox site must enable auto_install"
  }

  # --- zone_tag passes through ---
  assert {
    condition     = cloudflare_web_analytics_site.this["alexfreidah"].zone_tag == "zone-af"
    error_message = "alexfreidah site must reference zone-af"
  }
}

# -------------------------------------------------------------------------
# empty inputs create no resources
# -------------------------------------------------------------------------

run "empty_inputs_no_resources" {
  command = plan

  variables {
    sites = {}
  }

  # --- no sites when the map is empty ---
  assert {
    condition     = length(cloudflare_web_analytics_site.this) == 0
    error_message = "empty sites -> no cloudflare_web_analytics_site resources"
  }
}
