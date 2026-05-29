# -----------------------------------------------------------------------------
# PIHOLE-CONFIG MODULE - PROVIDER CONFIG
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
