# -----------------------------------------------------------------------------
# ramble module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the for_each fan-out: each var.resources entry plans one
# ramble_resource named by its key in var.namespace, with its fields passed
# through and an omitted file_path planned as the empty string. Also covers the
# empty map and the type validation.
# -----------------------------------------------------------------------------

mock_provider "ramble" {}

variables {
  ramble_token = "mock-token"
  namespace    = "zz-mock"

  resources = {
    "mock-pack" = {
      type           = "pack"
      repository_url = "https://github.com/mock/mock-pack"
      description    = "mock pack"
      license        = "MIT"
      tags           = ["nomad", "nomad-pack"]
      version        = "v1.0.0"
    }
  }
}

# -------------------------------------------------------------------------
# One ramble_resource per entry, named by its key in the namespace
# -------------------------------------------------------------------------

run "resources_for_each" {
  command = plan

  # --- one entry -> one resource ---
  assert {
    condition     = length(ramble_resource.this) == 1
    error_message = "one resources entry -> one ramble_resource"
  }

  # --- the key names the resource in var.namespace ---
  assert {
    condition     = ramble_resource.this["mock-pack"].name == "mock-pack" && ramble_resource.this["mock-pack"].namespace == "zz-mock"
    error_message = "the entry key names the resource in var.namespace"
  }

  # --- type, version and tags pass through ---
  assert {
    condition     = ramble_resource.this["mock-pack"].type == "pack" && ramble_resource.this["mock-pack"].version == "v1.0.0" && length(ramble_resource.this["mock-pack"].tags) == 2
    error_message = "type, version and tags pass through to the resource"
  }
}

# -------------------------------------------------------------------------
# An omitted file_path plans as the empty string, the provider default
# -------------------------------------------------------------------------

run "file_path_default" {
  command = plan

  # --- no file_path in the entry -> "" ---
  assert {
    condition     = ramble_resource.this["mock-pack"].file_path == ""
    error_message = "an omitted file_path plans as the empty string"
  }
}

# -------------------------------------------------------------------------
# An empty map plans no resources
# -------------------------------------------------------------------------

run "empty_resources" {
  command = plan

  variables {
    resources = {}
  }

  # --- no entries -> no resources ---
  assert {
    condition     = length(ramble_resource.this) == 0
    error_message = "an empty resources map -> no ramble_resource"
  }
}

# -------------------------------------------------------------------------
# A type other than pack or job fails validation
# -------------------------------------------------------------------------

run "type_validation" {
  command = plan

  variables {
    resources = {
      "mock-chart" = {
        type           = "chart"
        repository_url = "https://github.com/mock/mock-chart"
        description    = "mock chart"
        license        = "MIT"
        tags           = []
        version        = "v1.0.0"
      }
    }
  }

  expect_failures = [var.resources]
}
