# -----------------------------------------------------------------------------
# PI-HOLE DNS MODULE - VARIABLES
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PIHOLE PROVIDER AUTH (primary = green, secondary = logan)
# -----------------------------------------------------------------------------

variable "pihole_primary_url" {
  description = "URL for the primary (green) Pi-hole instance."
  type        = string
}

variable "pihole_secondary_url" {
  description = "URL for the secondary (logan) Pi-hole instance."
  type        = string
}

variable "pihole_password_primary" {
  description = "Primary Pi-hole password; sourced from TF_VAR_pihole_password_primary via env_helper."
  type        = string
  sensitive   = true
}

variable "pihole_password_secondary" {
  description = "Secondary Pi-hole password; sourced from TF_VAR_pihole_password_secondary via env_helper."
  type        = string
  sensitive   = true
}

variable "dns_records" {
  description = "Map of DNS A records to create"
  type = map(object({
    domain = string
    ip     = string
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create"
  type = map(object({
    domain = string
    target = string
  }))
  default = {}
}
