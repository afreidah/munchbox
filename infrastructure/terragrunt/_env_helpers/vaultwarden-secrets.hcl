# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS ENV HELPER
# -----------------------------------------------------------------------------
#
# Syncs credentials from HashiCorp Vault to Vaultwarden for human access.
# Data lives here (folders + login_items + secure_note_items) rather than
# root.hcl because it's all vaultwarden-shape and isn't reused elsewhere.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/vaultwarden-secrets"
}

inputs = {
  # --- bitwarden provider auth (was in root.hcl's generate "providers") ---
  bitwarden_server          = "https://vaultwarden.munchbox.cc"
  bitwarden_email           = "alex.freidah@gmail.com"
  bitwarden_master_password = get_env("VAULTWARDEN_MASTER_PASSWORD", "")

  vault_mount = "secret"

  folders = {
    admin  = "Admin Services"
    shared = "Shared"
  }

  login_items = {
    grafana = {
      name           = "Grafana Admin"
      uri            = "https://grafana.munchbox.cc"
      vault_path     = "grafana"
      username_field = "admin_user"
      password_field = "admin_password"
      folder_key     = "admin"
    }
    pihole_green = {
      name           = "Pi-hole (green)"
      uri            = "https://pihole-green.munchbox.cc/admin"
      vault_path     = "pihole/green"
      password_field = "password"
      folder_key     = "admin"
    }
    pihole_logan = {
      name           = "Pi-hole (logan)"
      uri            = "https://pihole-logan.munchbox.cc/admin"
      vault_path     = "pihole/logan"
      password_field = "password"
      folder_key     = "admin"
    }
    deluge = {
      name           = "Deluge"
      uri            = "https://deluge.munchbox.cc"
      vault_path     = "deluge"
      password_field = "web_password"
      folder_key     = "shared"
      notes          = "Synced from HashiCorp Vault - Shared with family"
    }
    aptly = {
      name           = "Aptly Package Repo"
      uri            = "https://apt.munchbox.cc/ui/"
      vault_path     = "aptly"
      username       = "admin"
      password_field = "password"
      folder_key     = "admin"
    }
  }

  secure_note_items = {
    break_glass = {
      name          = "SSH Break-Glass Key"
      vault_path    = "ssh/break-glass"
      content_field = "private_key"
      folder_key    = "admin"
      notes         = "Emergency SSH access to all cluster nodes when Vault/certs are unavailable. Save to file (chmod 600), then: ssh -i /path/to/key root@<node>"
    }
  }
}
