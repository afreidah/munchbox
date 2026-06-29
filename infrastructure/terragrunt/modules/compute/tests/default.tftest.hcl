# -----------------------------------------------------------------------------
# compute (wrapper) module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts provider_type routes to exactly one sub-module (aws/oci/proxmox)
# and that the other sub-modules are skipped (count = 0), plus the normalized
# and provider-specific OUTPUTS for each routing case.
#
# NOTE: the compute module's versions.tf omits `aws` from required_providers
# (it lists only oci + proxmox), so the implied AWS provider that the
# compute-spot sub-module needs cannot be bound by a `mock_provider "aws"`
# block -- Terraform would demand an explicit provider configuration and try
# to validate real credentials. To keep the test hermetic and plan-only, the
# AWS routing case overrides the whole `module.aws` sub-module with canned
# outputs (override_module), so the AWS provider is never configured.
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-mockmockmockmockm" }
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

  # The AWS provider is not declared in the module's required_providers, so
  # override the whole sub-module instead of mocking the provider. This makes
  # module.aws[0]'s outputs known at plan time without touching AWS.
  override_module {
    target = module.aws[0]
    outputs = {
      spot_instance_id      = "i-mock00000000000"
      public_ip             = "203.0.113.20"
      private_ip            = "10.0.0.20"
      ssh_connection_string = "ssh ubuntu@203.0.113.20"
    }
  }

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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "aws"
    error_message = "output.provider_type must be aws"
  }

  # --- OUTPUT: name echoes the input ---
  assert {
    condition     = output.name == var.name
    error_message = "output.name must equal var.name"
  }

  # --- OUTPUT: normalized id comes from the AWS instance id ---
  assert {
    condition     = output.id == "i-mock00000000000"
    error_message = "output.id must equal the AWS spot instance id"
  }

  # --- OUTPUT: public_ip comes from the AWS sub-module ---
  assert {
    condition     = output.public_ip == "203.0.113.20"
    error_message = "output.public_ip must equal the AWS public ip"
  }

  # --- OUTPUT: private_ip comes from the AWS sub-module ---
  assert {
    condition     = output.private_ip == "10.0.0.20"
    error_message = "output.private_ip must equal the AWS private ip"
  }

  # --- OUTPUT: ssh_connection_string comes from the AWS sub-module ---
  assert {
    condition     = output.ssh_connection_string == "ssh ubuntu@203.0.113.20"
    error_message = "output.ssh_connection_string must equal the AWS ssh string"
  }

  # --- OUTPUT: aws raw output present, oci/proxmox null ---
  assert {
    condition     = output.aws != null
    error_message = "output.aws must be set for provider_type=aws"
  }
  assert {
    condition     = output.oci == null
    error_message = "output.oci must be null for provider_type=aws"
  }
  assert {
    condition     = output.proxmox == null
    error_message = "output.proxmox must be null for provider_type=aws"
  }
}

# -------------------------------------------------------------------------
# provider_type = oci -> only OCI sub-module fires
# -------------------------------------------------------------------------

run "oci_only" {
  command = plan

  override_module {
    target = module.oci[0]
    outputs = {
      instance_id           = "ocid1.instance.oc1..mock"
      public_ip             = "150.136.0.10"
      private_ip            = "10.0.1.10"
      ssh_connection_string = "ssh ubuntu@150.136.0.10"
    }
  }

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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "oci"
    error_message = "output.provider_type must be oci"
  }

  # --- OUTPUT: name echoes the input ---
  assert {
    condition     = output.name == var.name
    error_message = "output.name must equal var.name"
  }

  # --- OUTPUT: normalized id comes from the OCI instance id ---
  assert {
    condition     = output.id == "ocid1.instance.oc1..mock"
    error_message = "output.id must equal the OCI instance id"
  }

  # --- OUTPUT: public_ip comes from the OCI sub-module ---
  assert {
    condition     = output.public_ip == "150.136.0.10"
    error_message = "output.public_ip must equal the OCI public ip"
  }

  # --- OUTPUT: private_ip comes from the OCI sub-module ---
  assert {
    condition     = output.private_ip == "10.0.1.10"
    error_message = "output.private_ip must equal the OCI private ip"
  }

  # --- OUTPUT: ssh_connection_string comes from the OCI sub-module ---
  assert {
    condition     = output.ssh_connection_string == "ssh ubuntu@150.136.0.10"
    error_message = "output.ssh_connection_string must equal the OCI ssh string"
  }

  # --- OUTPUT: oci raw output present, aws/proxmox null ---
  assert {
    condition     = output.oci != null
    error_message = "output.oci must be set for provider_type=oci"
  }
  assert {
    condition     = output.aws == null
    error_message = "output.aws must be null for provider_type=oci"
  }
  assert {
    condition     = output.proxmox == null
    error_message = "output.proxmox must be null for provider_type=oci"
  }
}

# -------------------------------------------------------------------------
# provider_type = proxmox -> only Proxmox sub-module fires
# -------------------------------------------------------------------------

run "proxmox_only" {
  command = plan

  override_module {
    target = module.proxmox[0]
    outputs = {
      id                    = 999
      default_ipv4_address  = "192.168.68.50"
      ssh_connection_string = "ssh root@192.168.68.50"
    }
  }

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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "proxmox"
    error_message = "output.provider_type must be proxmox"
  }

  # --- OUTPUT: name echoes the input ---
  assert {
    condition     = output.name == var.name
    error_message = "output.name must equal var.name"
  }

  # --- OUTPUT: normalized id comes from the Proxmox vmid ---
  assert {
    condition     = output.id == "999"
    error_message = "output.id must equal the Proxmox vmid (as string)"
  }

  # --- OUTPUT: public_ip comes from the Proxmox default ipv4 ---
  assert {
    condition     = output.public_ip == "192.168.68.50"
    error_message = "output.public_ip must equal the Proxmox default ipv4"
  }

  # --- OUTPUT: private_ip comes from the Proxmox default ipv4 ---
  assert {
    condition     = output.private_ip == "192.168.68.50"
    error_message = "output.private_ip must equal the Proxmox default ipv4"
  }

  # --- OUTPUT: ssh_connection_string comes from the Proxmox sub-module ---
  assert {
    condition     = output.ssh_connection_string == "ssh root@192.168.68.50"
    error_message = "output.ssh_connection_string must equal the Proxmox ssh string"
  }

  # --- OUTPUT: proxmox raw output present, aws/oci null ---
  assert {
    condition     = output.proxmox != null
    error_message = "output.proxmox must be set for provider_type=proxmox"
  }
  assert {
    condition     = output.aws == null
    error_message = "output.aws must be null for provider_type=proxmox"
  }
  assert {
    condition     = output.oci == null
    error_message = "output.oci must be null for provider_type=proxmox"
  }
}
