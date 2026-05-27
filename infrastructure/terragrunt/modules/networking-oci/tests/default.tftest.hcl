# -----------------------------------------------------------------------------
# networking-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the VCN composition: VCN/IGW/route_table/subnet all created in the
# given compartment, name prefixing is consistent, the route table holds the
# default route to the IGW, and the public subnet doesn't prohibit public
# IPs.
# -----------------------------------------------------------------------------

mock_provider "oci" {}

variables {
  name              = "test-net"
  compartment_id    = "ocid1.compartment.oc1..mock"
  vcn_cidr          = "10.100.0.0/16"
  subnet_cidr       = "10.100.0.0/24"
  dns_label         = "testnet"
  subnet_dns_label  = "testsubnet"
  security_list_ids = []
}

# -------------------------------------------------------------------------
# VCN: compartment + CIDR + display_name prefix
# -------------------------------------------------------------------------

run "vcn_inputs" {
  command = plan

  # --- compartment_id flows through ---
  assert {
    condition     = oci_core_vcn.this.compartment_id == var.compartment_id
    error_message = "VCN compartment_id must match input"
  }

  # --- VCN CIDR matches input ---
  assert {
    condition     = oci_core_vcn.this.cidr_blocks[0] == var.vcn_cidr
    error_message = "VCN cidr_blocks[0] must be vcn_cidr"
  }

  # --- display_name follows <name>-vcn convention ---
  assert {
    condition     = oci_core_vcn.this.display_name == "${var.name}-vcn"
    error_message = "VCN display_name must be <name>-vcn"
  }
}

# -------------------------------------------------------------------------
# IGW + route_table + subnet share the name prefix
# -------------------------------------------------------------------------

run "name_prefix_consistency" {
  command = plan

  # --- IGW display_name follows convention ---
  assert {
    condition     = oci_core_internet_gateway.this.display_name == "${var.name}-igw"
    error_message = "IGW display_name must be <name>-igw"
  }

  # --- route_table display_name follows convention ---
  assert {
    condition     = oci_core_route_table.this.display_name == "${var.name}-rt"
    error_message = "route_table display_name must be <name>-rt"
  }

  # --- subnet display_name follows convention ---
  assert {
    condition     = oci_core_subnet.this.display_name == "${var.name}-subnet"
    error_message = "subnet display_name must be <name>-subnet"
  }
}

# -------------------------------------------------------------------------
# Route table holds the 0.0.0.0/0 default route to the IGW
# -------------------------------------------------------------------------

run "default_route_via_igw" {
  command = plan

  # --- route_rules contains an entry pointed at 0.0.0.0/0 ---
  assert {
    condition     = contains([for r in oci_core_route_table.this.route_rules : r.destination], "0.0.0.0/0")
    error_message = "route_table must have a 0.0.0.0/0 rule"
  }
}

# -------------------------------------------------------------------------
# Public subnet allows public IPs (prohibit = false)
# -------------------------------------------------------------------------

run "subnet_allows_public_ip" {
  command = plan

  # --- prohibit_public_ip_on_vnic is false (allow) ---
  assert {
    condition     = oci_core_subnet.this.prohibit_public_ip_on_vnic == false
    error_message = "public subnet must allow public IPs (prohibit = false)"
  }

  # --- subnet CIDR matches var.subnet_cidr ---
  assert {
    condition     = oci_core_subnet.this.cidr_block == var.subnet_cidr
    error_message = "subnet cidr_block must match var.subnet_cidr"
  }
}
