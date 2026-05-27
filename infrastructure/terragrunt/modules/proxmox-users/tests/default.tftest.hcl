# -----------------------------------------------------------------------------
# proxmox-users module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the roles + users for_each maps fan out 1:1, the vault data source
# only fires for users with a vault_path (the for-comprehension filter), and
# user_id flows through cleanly.
# -----------------------------------------------------------------------------

mock_provider "proxmox" {}

mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = { password = "mock-pw" }
    }
  }
}

variables {
  roles = {
    "prometheus-exporter" = { privileges = ["Sys.Audit", "VM.Audit"] }
    "backup-reader"       = { privileges = ["Datastore.Audit"] }
  }
  users = {
    "prometheus" = {
      user_id    = "prometheus@pve"
      comment    = "PVE Exporter"
      vault_path = "proxmox/prometheus"
      acls       = []
    }
    "static-pw-user" = {
      user_id  = "static@pve"
      password = "literal-password"
      acls     = []
    }
  }
}

# -------------------------------------------------------------------------
# Roles for_each: one resource per map key
# -------------------------------------------------------------------------

run "roles_for_each" {
  command = plan

  # --- two roles input -> two role resources ---
  assert {
    condition     = length(proxmox_virtual_environment_role.role) == 2
    error_message = "two roles -> two role resources"
  }

  # --- prometheus-exporter key exists in the for_each map ---
  assert {
    condition     = contains(keys(proxmox_virtual_environment_role.role), "prometheus-exporter")
    error_message = "prometheus-exporter role key must exist"
  }
}

# -------------------------------------------------------------------------
# Users for_each: one resource per map key; user_id propagates
# -------------------------------------------------------------------------

run "users_for_each" {
  command = plan

  # --- two users input -> two user resources ---
  assert {
    condition     = length(proxmox_virtual_environment_user.user) == 2
    error_message = "two users -> two user resources"
  }

  # --- user_id propagates from var.users[key].user_id ---
  assert {
    condition     = proxmox_virtual_environment_user.user["prometheus"].user_id == "prometheus@pve"
    error_message = "user_id must propagate from var.users[key]"
  }
}

# -------------------------------------------------------------------------
# Vault lookup filter: only users with vault_path trigger a data source
# -------------------------------------------------------------------------

run "vault_lookup_filter" {
  command = plan

  # --- only the vault_path-having user appears in the data-source map ---
  assert {
    condition     = length(data.vault_kv_secret_v2.user_password) == 1
    error_message = "only the vault_path-having user triggers a vault lookup"
  }

  # --- prometheus user has vault_path so its data source exists ---
  assert {
    condition     = contains(keys(data.vault_kv_secret_v2.user_password), "prometheus")
    error_message = "vault lookup must be for the 'prometheus' user"
  }
}

# -------------------------------------------------------------------------
# Empty inputs: zero resources, no errors
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    roles = {}
    users = {}
  }

  # --- empty roles + users -> zero role + zero user resources ---
  assert {
    condition     = length(proxmox_virtual_environment_role.role) == 0 && length(proxmox_virtual_environment_user.user) == 0
    error_message = "empty roles+users maps -> zero resources"
  }
}
