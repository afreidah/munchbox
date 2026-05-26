# -----------------------------------------------------------------------------
# BLOCK VOLUME MODULE (OCI) - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "volumes" {
  description = "Map of created block volumes keyed by name"
  value = {
    for name, vol in oci_core_volume.this : name => {
      id      = vol.id
      size_gb = vol.size_in_gbs
    }
  }
}

output "attachments" {
  description = "Map of volume attachments keyed by volume name"
  value = {
    for name, att in oci_core_volume_attachment.this : name => {
      id     = att.id
      device = att.device
      iqn    = att.iqn
      ipv4   = att.ipv4
      port   = att.port
    }
  }
}
