# -----------------------------------------------------------------------------
# PI-HOLE DNS MODULE
# -----------------------------------------------------------------------------
#
# Manages local DNS records in Pi-hole for split-horizon DNS. Creates A records
# (pihole_local_dns) and CNAME records (pihole_cname_record) on both Pi-hole
# instances (primary = green, secondary = logan) for redundancy.
#
# Uses dklesev/pihole (v6 REST API). Inputs keep the caller-facing `.domain`
# field for back-compat; module remaps it to dklesev's `hostname` arg.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DNS A RECORDS - PRIMARY (green)
# -----------------------------------------------------------------------------

resource "pihole_local_dns" "primary" {
  provider = pihole.primary
  for_each = var.dns_records

  hostname = each.value.domain
  ip       = each.value.ip
}

# -----------------------------------------------------------------------------
# DNS A RECORDS - SECONDARY (logan)
# -----------------------------------------------------------------------------

resource "pihole_local_dns" "secondary" {
  provider = pihole.secondary
  for_each = var.dns_records

  hostname = each.value.domain
  ip       = each.value.ip
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
