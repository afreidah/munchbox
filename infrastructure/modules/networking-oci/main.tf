# -----------------------------------------------------------------------------
# NETWORKING MODULE - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# Simple VCN networking for Oracle Cloud deployments. Creates a public subnet
# with internet access - no NAT Gateway costs.
#
# Components Created:
#   - VCN (Virtual Cloud Network)
#   - Internet Gateway
#   - Route Table with internet access
#   - Public Subnet
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VCN
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name}-vcn"
  dns_label      = var.dns_label
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# -----------------------------------------------------------------------------

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-igw"
  enabled        = true
}

# -----------------------------------------------------------------------------
# ROUTE TABLE
# -----------------------------------------------------------------------------

resource "oci_core_route_table" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name}-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNET
# -----------------------------------------------------------------------------

resource "oci_core_subnet" "this" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.name}-subnet"
  dns_label                  = var.subnet_dns_label
  route_table_id             = oci_core_route_table.this.id
  security_list_ids          = var.security_list_ids
  prohibit_public_ip_on_vnic = false
}
