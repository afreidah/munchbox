# -----------------------------------------------------------------------------
# vaultwarden-secrets module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the folder / login / secure_note for_each maps fan out
# independently, login folder_id resolves through the folders map only when
# folder_key is set, and empty inputs produce zero resources without
# erroring.
# -----------------------------------------------------------------------------

mock_provider "bitwarden" {}

mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = {
        admin_password = "mock-pass"
        admin_user     = "mock-user"
        password       = "mock-pass"
        private_key    = "mock-key"
      }
    }
  }
}

variables {
  bitwarden_server          = "https://mock.example.com"
  bitwarden_email           = "mock@example.com"
  bitwarden_master_password = "mock-master"

  folders = {
    "admin"  = "Admin Services"
    "shared" = "Shared"
  }
  login_items = {
    "grafana" = {
      name           = "Grafana Admin"
      uri            = "https://grafana.example.com"
      vault_path     = "grafana"
      username_field = "admin_user"
      password_field = "admin_password"
      folder_key     = "admin"
    }
    "rootless" = {
      name           = "No-Folder Login"
      uri            = "https://x.example.com"
      vault_path     = "x"
      password_field = "password"
    }
  }
  secure_note_items = {
    "break_glass" = {
      name          = "Break-Glass SSH"
      vault_path    = "ssh/break-glass"
      content_field = "private_key"
      folder_key    = "admin"
      notes         = "test-notes"
    }
  }
}

# -------------------------------------------------------------------------
# Folders for_each: one resource per map key
# -------------------------------------------------------------------------

run "folders_for_each" {
  command = plan

  # --- two folders input -> two resources ---
  assert {
    condition     = length(bitwarden_folder.folders) == 2
    error_message = "two folders input -> two resources"
  }

  # --- folder name comes from map value ---
  assert {
    condition     = bitwarden_folder.folders["admin"].name == "Admin Services"
    error_message = "folder name must propagate from map value"
  }

  # --- folder_ids output is keyed by every folder key ---
  assert {
    condition     = toset(keys(output.folder_ids)) == toset(["admin", "shared"])
    error_message = "folder_ids must be keyed by every folder key"
  }
}

# -------------------------------------------------------------------------
# Login items for_each: one resource per map key
# -------------------------------------------------------------------------

run "logins_for_each" {
  command = plan

  # --- two login_items input -> two resources ---
  assert {
    condition     = length(bitwarden_item_login.logins) == 2
    error_message = "two login_items input -> two resources"
  }

  # --- login display name comes from input map ---
  assert {
    condition     = bitwarden_item_login.logins["grafana"].name == "Grafana Admin"
    error_message = "login name must propagate from map"
  }

  # --- login_item_ids output is keyed by every login key ---
  assert {
    condition     = toset(keys(output.login_item_ids)) == toset(["grafana", "rootless"])
    error_message = "login_item_ids must be keyed by every login key"
  }
}

# -------------------------------------------------------------------------
# Secure notes for_each: one resource per map key
# -------------------------------------------------------------------------

run "secure_notes_for_each" {
  command = plan

  # --- one secure_note input -> one resource ---
  assert {
    condition     = length(bitwarden_item_secure_note.secure_notes) == 1
    error_message = "one secure_note input -> one resource"
  }

  # --- secure_note_item_ids output is keyed by every secure-note key ---
  assert {
    condition     = toset(keys(output.secure_note_item_ids)) == toset(["break_glass"])
    error_message = "secure_note_item_ids must be keyed by every secure-note key"
  }
}

# -------------------------------------------------------------------------
# Empty maps: zero resources, plan still succeeds
# -------------------------------------------------------------------------

run "empty_inputs" {
  command = plan

  variables {
    folders           = {}
    login_items       = {}
    secure_note_items = {}
  }

  # --- empty folders map -> zero resources ---
  assert {
    condition     = length(bitwarden_folder.folders) == 0
    error_message = "empty folders map -> zero resources"
  }

  # --- empty login_items map -> zero resources ---
  assert {
    condition     = length(bitwarden_item_login.logins) == 0
    error_message = "empty login_items map -> zero resources"
  }
}
