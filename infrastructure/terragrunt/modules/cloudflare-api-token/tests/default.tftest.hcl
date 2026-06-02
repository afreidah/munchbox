# -----------------------------------------------------------------------------
# cloudflare-api-token module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Tokens use empty policies so plan does not index the permission-groups data
# source, whose result is a provider nested_type list that terraform-test
# cannot mock ("expected object type, found tuple"). This exercises the
# per-token for_each fan-out; the name->ID resolution path is covered live
# (the module mints real tokens against the API).
# -----------------------------------------------------------------------------

mock_provider "cloudflare" {}

variables {
  tokens = {
    wandns = {
      name     = "munchbox-wandns-dns-edit"
      policies = []
    }
  }
}

# -------------------------------------------------------------------------
# one token request renders one cloudflare_api_token
# -------------------------------------------------------------------------

run "single_token_fan_out" {
  command = plan

  assert {
    condition     = length(cloudflare_api_token.this) == 1
    error_message = "one token request -> one cloudflare_api_token"
  }
}

# -------------------------------------------------------------------------
# multiple token requests fan out independently
# -------------------------------------------------------------------------

run "multi_token_fan_out" {
  command = plan

  variables {
    tokens = {
      wandns = {
        name     = "munchbox-wandns-dns-edit"
        policies = []
      }
      logs = {
        name     = "munchbox-log-collector-analytics"
        policies = []
      }
    }
  }

  assert {
    condition     = length(cloudflare_api_token.this) == 2
    error_message = "two token requests -> two cloudflare_api_token resources"
  }
}
