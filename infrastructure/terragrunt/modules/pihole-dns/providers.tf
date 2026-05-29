# -----------------------------------------------------------------------------
# PIHOLE-DNS MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------
#
# Two aliased pihole provider instances: primary = green, secondary = logan.
# URLs + passwords are supplied by the env_helper; passwords come from
# TF_VAR_pihole_password_{primary,secondary} via munchbox-env.sh.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

provider "pihole" {
  alias    = "primary"
  url      = var.pihole_primary_url
  password = var.pihole_password_primary
}

provider "pihole" {
  alias    = "secondary"
  url      = var.pihole_secondary_url
  password = var.pihole_password_secondary
}
