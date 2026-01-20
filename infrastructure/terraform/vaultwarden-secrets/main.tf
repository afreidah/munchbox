# -------------------------------------------------------------------------------
# Vaultwarden Secrets Management
#
# Project: Munchbox / Author: Alex Freidah
#
# Syncs service credentials from HashiCorp Vault to Vaultwarden for human access.
# Uses the maxlaverse/bitwarden Terraform provider with embedded client.
# -------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.12"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.25"
    }
  }

  backend "consul" {
    address = "stabler:8500"
    scheme  = "http"
    path    = "terraform/vaultwarden-secrets"
  }
}

# -------------------------------------------------------------------------
# Vault Provider & Secrets
# -------------------------------------------------------------------------

provider "vault" {
  address = "https://192.168.68.61:8200"
}

# Pull credentials from HashiCorp Vault
data "vault_kv_secret_v2" "nextcloud" {
  mount = "secret"
  name  = "nextcloud"
}

data "vault_kv_secret_v2" "grafana" {
  mount = "secret"
  name  = "grafana"
}

data "vault_kv_secret_v2" "deluge" {
  mount = "secret"
  name  = "deluge"
}

data "vault_kv_secret_v2" "pihole_green" {
  mount = "secret"
  name  = "pihole/green"
}

data "vault_kv_secret_v2" "pihole_logan" {
  mount = "secret"
  name  = "pihole/logan"
}

data "vault_kv_secret_v2" "vaultwarden" {
  mount = "secret"
  name  = "vaultwarden"
}

# -------------------------------------------------------------------------
# Bitwarden/Vaultwarden Provider
# -------------------------------------------------------------------------

provider "bitwarden" {
  server          = "https://vaultwarden.munchbox.cc"
  email           = "alex.freidah@gmail.com"
  master_password = var.vaultwarden_master_password
}

variable "vaultwarden_master_password" {
  description = "Master password for Vaultwarden"
  type        = string
  sensitive   = true
}

# -------------------------------------------------------------------------
# Vaultwarden Folders
# -------------------------------------------------------------------------

resource "bitwarden_folder" "admin" {
  name = "Admin Services"
}

resource "bitwarden_folder" "shared" {
  name = "Shared"
}

# -------------------------------------------------------------------------
# Login Items - Admin Services
# -------------------------------------------------------------------------

resource "bitwarden_item_login" "nextcloud" {
  name      = "Nextcloud Admin"
  folder_id = bitwarden_folder.admin.id
  username  = "admin"
  password  = data.vault_kv_secret_v2.nextcloud.data["admin_password"]

  uri {
    value = "https://nextcloud.munchbox.cc"
  }

  notes = "Synced from HashiCorp Vault"
}

resource "bitwarden_item_login" "grafana" {
  name      = "Grafana Admin"
  folder_id = bitwarden_folder.admin.id
  username  = data.vault_kv_secret_v2.grafana.data["admin_user"]
  password  = data.vault_kv_secret_v2.grafana.data["admin_password"]

  uri {
    value = "https://grafana.munchbox.cc"
  }

  notes = "Synced from HashiCorp Vault"
}

resource "bitwarden_item_login" "pihole_green" {
  name      = "Pi-hole (green)"
  folder_id = bitwarden_folder.admin.id
  password  = data.vault_kv_secret_v2.pihole_green.data["password"]

  uri {
    value = "https://green.munchbox.cc/admin"
  }

  notes = "Synced from HashiCorp Vault"
}

resource "bitwarden_item_login" "pihole_logan" {
  name      = "Pi-hole (logan)"
  folder_id = bitwarden_folder.admin.id
  password  = data.vault_kv_secret_v2.pihole_logan.data["password"]

  uri {
    value = "https://logan.munchbox.cc/admin"
  }

  notes = "Synced from HashiCorp Vault"
}

# -------------------------------------------------------------------------
# Login Items - Shared Services
# -------------------------------------------------------------------------

resource "bitwarden_item_login" "deluge" {
  name      = "Deluge"
  folder_id = bitwarden_folder.shared.id
  password  = data.vault_kv_secret_v2.deluge.data["web_password"]

  uri {
    value = "https://deluge.munchbox.cc"
  }

  notes = "Synced from HashiCorp Vault - Shared with family"
}
