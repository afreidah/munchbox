# -----------------------------------------------------------------------------
# VAULTWARDEN-SECRETS MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Bitwarden provider auth is supplied by the env_helper as inputs. Master
# password is read from VAULTWARDEN_MASTER_PASSWORD on the workstation /
# CI runner; munchbox-env.sh exports it.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "bitwarden" {
  server          = var.bitwarden_server
  email           = var.bitwarden_email
  master_password = var.bitwarden_master_password
}
