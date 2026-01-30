# -----------------------------------------------------------------------------
# SECURITY LIST MODULE (OCI) - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "security_list_id" {
  description = "OCID of the security list"
  value       = oci_core_security_list.this.id
}

output "security_list_name" {
  description = "Display name of the security list"
  value       = oci_core_security_list.this.display_name
}
