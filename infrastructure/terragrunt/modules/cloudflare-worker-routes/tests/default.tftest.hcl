# -----------------------------------------------------------------------------
# cloudflare-worker-routes module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts one script per workers entry and one route per route entry, that
# routes are keyed per script so two workers can share a pattern, and that an
# empty map deploys nothing.
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}
mock_provider "aws" {}

variables {
  cloudflare_api_token = "mock-token"
  account_id           = "00000000000000000000000000000000"

  workers = {
    "security-txt" = {
      content = "export default { fetch() { return new Response(\"ok\"); } };"
      routes = {
        "munchbox.cc/.well-known/security.txt"     = "00000000000000000000000000000001"
        "alexfreidah.com/.well-known/security.txt" = "00000000000000000000000000000002"
      }
    }
  }
}

# -------------------------------------------------------------------------
# one script + one route per entry
# -------------------------------------------------------------------------

run "script_and_routes" {
  command = plan

  assert {
    condition     = cloudflare_workers_script.this["security-txt"].script_name == "security-txt"
    error_message = "the script should be created under its map key"
  }

  assert {
    condition     = length(cloudflare_workers_route.this) == 2
    error_message = "two routes entries -> two routes"
  }

  assert {
    condition     = output.script_names == ["security-txt"]
    error_message = "script_names output must list every deployed script"
  }

  assert {
    condition     = toset(output.route_patterns) == toset(["munchbox.cc/.well-known/security.txt", "alexfreidah.com/.well-known/security.txt"])
    error_message = "route_patterns must list every configured route pattern"
  }
}

# -------------------------------------------------------------------------
# several workers, and a pattern two of them share
# -------------------------------------------------------------------------

run "many_workers" {
  command = plan

  variables {
    workers = {
      "a" = {
        content = "export default {};"
        routes  = { "munchbox.cc/x" = "00000000000000000000000000000001" }
      }
      "b" = {
        content = "export default {};"
        routes  = { "munchbox.cc/x" = "00000000000000000000000000000002" }
      }
    }
  }

  # --- keying routes by script as well as pattern is what keeps these two
  #     from colliding into one entry ---
  assert {
    condition     = length(cloudflare_workers_script.this) == 2
    error_message = "two workers entries -> two scripts"
  }

  assert {
    condition     = length(cloudflare_workers_route.this) == 2
    error_message = "a pattern shared by two workers must stay two routes"
  }
}

# -------------------------------------------------------------------------
# bindings reach the script
# -------------------------------------------------------------------------

run "bindings" {
  command = plan

  variables {
    workers = {
      "bound" = {
        content = "export default {};"
        bindings = [
          { name = "ORIGIN_HOST", type = "plain_text", text = "example.com" },
          { name = "ORIGIN_SECRET_ACCESS_KEY", type = "secret_text", text = "shh" },
        ]
      }
    }
  }

  assert {
    condition     = length(cloudflare_workers_script.this["bound"].bindings) == 2
    error_message = "bindings must be attached to the script"
  }
}

# -------------------------------------------------------------------------
# empty map -> nothing, so a worker can be retired without emptying the leaf
# -------------------------------------------------------------------------

run "no_workers" {
  command = plan

  variables {
    workers = {}
  }

  assert {
    condition     = length(cloudflare_workers_script.this) == 0
    error_message = "empty workers map -> no scripts"
  }

  assert {
    condition     = length(cloudflare_workers_route.this) == 0
    error_message = "empty workers map -> no routes"
  }
}
