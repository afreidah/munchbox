# -----------------------------------------------------------------------------
# network (wrapper) module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the provider_type switch: only the AWS sub-modules fire for
# provider_type="aws", only the OCI sub-modules fire for "oci", and proxmox
# fires neither (it just references existing bridges).
# -----------------------------------------------------------------------------

mock_provider "aws" {}
mock_provider "oci" {}
mock_provider "proxmox" {}

variables {
  name        = "test-net"
  vpc_cidr    = "10.100.0.0/16"
  subnet_cidr = "10.100.1.0/24"
  tags        = { project = "munchbox" }
}

# -------------------------------------------------------------------------
# provider_type = "aws" fires AWS sub-modules only
# -------------------------------------------------------------------------

run "aws_only_when_provider_aws" {
  command = plan

  variables {
    provider_type = "aws"
    aws_config    = { availability_zones = ["us-east-1a"] }
  }

  # --- aws_networking sub-module count = 1 ---
  assert {
    condition     = length(module.aws_networking) == 1
    error_message = "aws_networking sub-module should fire for provider_type=aws"
  }

  # --- aws_security_group sub-module count = 1 ---
  assert {
    condition     = length(module.aws_security_group) == 1
    error_message = "aws_security_group sub-module should fire for provider_type=aws"
  }

  # --- oci_networking sub-module skipped ---
  assert {
    condition     = length(module.oci_networking) == 0
    error_message = "OCI sub-module should be skipped for provider_type=aws"
  }

  # --- oci_security_list sub-module skipped ---
  assert {
    condition     = length(module.oci_security_list) == 0
    error_message = "OCI security_list should be skipped for provider_type=aws"
  }
}

# -------------------------------------------------------------------------
# provider_type = "oci" fires OCI sub-modules only
# -------------------------------------------------------------------------

run "oci_only_when_provider_oci" {
  command = plan

  variables {
    provider_type = "oci"
    oci_config    = { compartment_id = "ocid1.compartment.oc1..mock" }
  }

  # --- oci_networking sub-module count = 1 ---
  assert {
    condition     = length(module.oci_networking) == 1
    error_message = "oci_networking sub-module should fire for provider_type=oci"
  }

  # --- oci_security_list sub-module count = 1 ---
  assert {
    condition     = length(module.oci_security_list) == 1
    error_message = "oci_security_list sub-module should fire for provider_type=oci"
  }

  # --- aws_networking sub-module skipped ---
  assert {
    condition     = length(module.aws_networking) == 0
    error_message = "AWS sub-module should be skipped for provider_type=oci"
  }
}

# -------------------------------------------------------------------------
# provider_type = "proxmox" fires nothing (just references existing bridges)
# -------------------------------------------------------------------------

run "proxmox_fires_nothing" {
  command = plan

  variables {
    provider_type  = "proxmox"
    proxmox_config = { network_bridge = "vmbr0" }
  }

  # --- aws_networking sub-module skipped ---
  assert {
    condition     = length(module.aws_networking) == 0
    error_message = "AWS should be skipped for provider_type=proxmox"
  }

  # --- oci_networking sub-module skipped ---
  assert {
    condition     = length(module.oci_networking) == 0
    error_message = "OCI should be skipped for provider_type=proxmox"
  }
}
