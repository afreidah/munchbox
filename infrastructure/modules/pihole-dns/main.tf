# -----------------------------------------------------------------------------
# PI-HOLE DNS MODULE
# -----------------------------------------------------------------------------
#
# Manages local DNS records in Pi-hole for split-horizon DNS. Creates A records
# and CNAME records on multiple Pi-hole instances to ensure redundancy.
#
# Components Created:
#   - Pi-hole DNS records (A records) on all instances
#   - Pi-hole CNAME records on all instances
#
# Architecture:
#   - Records defined via input variables
#   - Uses Pi-hole API with token authentication
#   - Manages multiple Pi-hole instances for HA
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS A RECORDS - PRIMARY (green)
# -----------------------------------------------------------------------------

resource "pihole_dns_record" "primary" {
  provider = pihole.primary
  for_each = var.dns_records

  domain = each.value.domain
  ip     = each.value.ip
}

# -----------------------------------------------------------------------------
# DNS A RECORDS - SECONDARY (logan)
# -----------------------------------------------------------------------------

resource "pihole_dns_record" "secondary" {
  provider = pihole.secondary
  for_each = var.dns_records

  domain = each.value.domain
  ip     = each.value.ip
}

# -----------------------------------------------------------------------------
# CNAME RECORDS - PRIMARY (green)
# -----------------------------------------------------------------------------

resource "pihole_cname_record" "primary" {
  provider = pihole.primary
  for_each = var.cname_records

  domain = each.value.domain
  target = each.value.target
}

# -----------------------------------------------------------------------------
# CNAME RECORDS - SECONDARY (logan)
# -----------------------------------------------------------------------------

resource "pihole_cname_record" "secondary" {
  provider = pihole.secondary
  for_each = var.cname_records

  domain = each.value.domain
  target = each.value.target
}
