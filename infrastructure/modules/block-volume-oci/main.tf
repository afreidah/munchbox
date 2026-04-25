# -----------------------------------------------------------------------------
# BLOCK VOLUME MODULE (OCI)
# -----------------------------------------------------------------------------
#
# Creates one or more OCI block volumes and attaches them to an instance.
# Formatting and mounting should be handled by Ansible or cloud-init.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

locals {
  volume_map = { for v in var.volumes : v.name => v }
}

resource "oci_core_volume" "this" {
  for_each = local.volume_map

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = each.value.name
  size_in_gbs         = each.value.size_gb
  vpus_per_gb         = each.value.vpus_per_gb
  freeform_tags       = var.tags
}

resource "oci_core_volume_attachment" "this" {
  for_each = local.volume_map

  attachment_type = each.value.attachment_type
  instance_id     = var.instance_id
  volume_id       = oci_core_volume.this[each.key].id
  display_name    = "${each.value.name}-attachment"
}
