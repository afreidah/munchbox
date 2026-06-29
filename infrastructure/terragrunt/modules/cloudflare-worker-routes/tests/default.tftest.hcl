# -----------------------------------------------------------------------------
# cloudflare-worker-routes module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts one Worker script is created and one route per routes entry, and that
# an empty routes map still creates the script but no routes.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  cloudflare_api_token = "mock-token"
  account_id           = "00000000000000000000000000000000"
  script_name          = "test-worker"
  content              = "export default { fetch() { return new Response(\"ok\"); } };"

  routes = {
    "munchbox.cc/.well-known/security.txt"     = "00000000000000000000000000000001"
    "alexfreidah.com/.well-known/security.txt" = "00000000000000000000000000000002"
  }
}

# -------------------------------------------------------------------------
# one script + one route per entry
# -------------------------------------------------------------------------

run "script_and_routes" {
  command = plan

  assert {
    condition     = cloudflare_workers_script.this.script_name == "test-worker"
    error_message = "the script should be created with the given name"
  }

  assert {
    condition     = length(cloudflare_workers_route.this) == 2
    error_message = "two routes entries -> two routes"
  }

  # --- script_name output mirrors the input script name ---
  assert {
    condition     = output.script_name == "test-worker"
    error_message = "script_name output must mirror the configured script name"
  }

  # --- route_patterns lists every route pattern ---
  assert {
    condition     = toset(output.route_patterns) == toset(["munchbox.cc/.well-known/security.txt", "alexfreidah.com/.well-known/security.txt"])
    error_message = "route_patterns must list every configured route pattern"
  }
}

# -------------------------------------------------------------------------
# empty routes -> script only, no routes
# -------------------------------------------------------------------------

run "no_routes" {
  command = plan

  variables {
    routes = {}
  }

  assert {
    condition     = length(cloudflare_workers_route.this) == 0
    error_message = "empty routes map -> no routes"
  }
}
