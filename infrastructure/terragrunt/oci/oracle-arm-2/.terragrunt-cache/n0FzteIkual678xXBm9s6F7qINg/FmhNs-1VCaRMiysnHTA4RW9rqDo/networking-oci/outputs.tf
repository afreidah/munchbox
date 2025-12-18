# -----------------------------------------------------------------------------
# NETWORKING MODULE (OCI) - OUTPUTS
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.this.id
}

output "vcn_cidr" {
  description = "CIDR block of the VCN"
  value       = var.vcn_cidr
}

output "internet_gateway_id" {
  description = "OCID of the Internet Gateway"
  value       = oci_core_internet_gateway.this.id
}

output "route_table_id" {
  description = "OCID of the route table"
  value       = oci_core_route_table.this.id
}

output "subnet_id" {
  description = "OCID of the subnet"
  value       = oci_core_subnet.this.id
}

output "subnet_cidr" {
  description = "CIDR block of the subnet"
  value       = var.subnet_cidr
}
