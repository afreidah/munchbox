# -----------------------------------------------------------------------------
# compute (wrapper) module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts provider_type routes to exactly one sub-module (aws/oci/proxmox)
# and that the other sub-modules are skipped (count = 0). Sub-module inputs
# aren't readable from the parent at plan time, so deeper input-assertions
# live in each sub-module's own tests/default.tftest.hcl.
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-mock" }
  }
}

mock_provider "oci" {
  mock_data "oci_identity_availability_domains" {
    defaults = { availability_domains = [{ name = "MockAD-1" }] }
  }
  mock_data "oci_core_images" {
    defaults = { images = [{ id = "ocid1.image..mock" }] }
  }
}

mock_provider "proxmox" {}

variables {
  name      = "test-node"
  cpu       = 2
  memory_gb = 4
  disk_gb   = 20
  ssh_key   = "ssh-ed25519 AAAA test"
}

# -------------------------------------------------------------------------
# provider_type = aws -> only AWS sub-module fires
# -------------------------------------------------------------------------

run "aws_only" {
  command = plan

  variables {
    provider_type = "aws"
    aws_config = {
      subnet_id          = "subnet-mock"
      security_group_ids = ["sg-mock"]
    }
  }

  # --- AWS sub-module count = 1 ---
  assert {
    condition     = length(module.aws) == 1
    error_message = "AWS sub-module should fire for provider_type=aws"
  }

  # --- OCI + Proxmox sub-modules skipped ---
  assert {
    condition     = length(module.oci) == 0 && length(module.proxmox) == 0
    error_message = "Other sub-modules should be skipped"
  }
}

# -------------------------------------------------------------------------
# provider_type = oci -> only OCI sub-module fires
# -------------------------------------------------------------------------

run "oci_only" {
  command = plan

  variables {
    provider_type = "oci"
    oci_config = {
      compartment_id      = "ocid1.compartment.oc1..mock"
      availability_domain = "1"
      subnet_id           = "ocid1.subnet.oc1..mock"
    }
  }

  # --- OCI sub-module count = 1 ---
  assert {
    condition     = length(module.oci) == 1
    error_message = "OCI sub-module should fire for provider_type=oci"
  }

  # --- AWS + Proxmox sub-modules skipped ---
  assert {
    condition     = length(module.aws) == 0 && length(module.proxmox) == 0
    error_message = "Other sub-modules should be skipped"
  }
}

# -------------------------------------------------------------------------
# provider_type = proxmox -> only Proxmox sub-module fires
# -------------------------------------------------------------------------

run "proxmox_only" {
  command = plan

  variables {
    provider_type = "proxmox"
    proxmox_config = {
      target_node = "pve"
      vmid        = 999
    }
  }

  # --- Proxmox sub-module count = 1 ---
  assert {
    condition     = length(module.proxmox) == 1
    error_message = "Proxmox sub-module should fire for provider_type=proxmox"
  }

  # --- AWS + OCI sub-modules skipped ---
  assert {
    condition     = length(module.aws) == 0 && length(module.oci) == 0
    error_message = "Other sub-modules should be skipped"
  }
}
