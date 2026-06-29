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

  # Override the AWS sub-modules so their outputs are known at plan time
  # (the AWS provider is mocked, so vpc_id etc. would otherwise be unknown).
  override_module {
    target = module.aws_networking[0]
    outputs = {
      vpc_id                = "vpc-mock00000000000"
      vpc_cidr              = "10.100.0.0/16"
      public_subnet_ids     = ["subnet-mock0", "subnet-mock1"]
      public_subnet_cidrs   = ["10.100.0.0/24", "10.100.1.0/24"]
      internet_gateway_id   = "igw-mock00000000000"
      public_route_table_id = "rtb-mock00000000000"
    }
  }

  override_module {
    target = module.aws_security_group[0]
    outputs = {
      security_group_id  = "sg-mock00000000000"
      security_group_arn = "arn:aws:ec2:us-east-1:000000000000:security-group/sg-mock00000000000"
    }
  }

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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "aws"
    error_message = "output.provider_type must be aws"
  }

  # --- OUTPUT: network_id is the AWS VPC id ---
  assert {
    condition     = output.network_id == "vpc-mock00000000000"
    error_message = "output.network_id must equal the AWS vpc id"
  }

  # --- OUTPUT: subnet_id is the first public subnet ---
  assert {
    condition     = output.subnet_id == "subnet-mock0"
    error_message = "output.subnet_id must equal the first public subnet id"
  }

  # --- OUTPUT: subnet_ids is the public subnet list ---
  assert {
    condition     = toset(output.subnet_ids) == toset(["subnet-mock0", "subnet-mock1"])
    error_message = "output.subnet_ids must equal the public subnet ids"
  }

  # --- OUTPUT: security_group_id is the AWS sg id ---
  assert {
    condition     = output.security_group_id == "sg-mock00000000000"
    error_message = "output.security_group_id must equal the AWS sg id"
  }

  # --- OUTPUT: vpc_cidr is the AWS vpc cidr ---
  assert {
    condition     = output.vpc_cidr == "10.100.0.0/16"
    error_message = "output.vpc_cidr must equal the AWS vpc cidr"
  }

  # --- OUTPUT: subnet_cidr is the first public subnet cidr ---
  assert {
    condition     = output.subnet_cidr == "10.100.0.0/24"
    error_message = "output.subnet_cidr must equal the first public subnet cidr"
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
# provider_type = "oci" fires OCI sub-modules only
# -------------------------------------------------------------------------

run "oci_only_when_provider_oci" {
  command = plan

  override_module {
    target = module.oci_networking[0]
    outputs = {
      vcn_id      = "ocid1.vcn.oc1..mock"
      vcn_cidr    = "10.100.0.0/16"
      subnet_id   = "ocid1.subnet.oc1..mock"
      subnet_cidr = "10.100.1.0/24"
    }
  }

  override_module {
    target = module.oci_security_list[0]
    outputs = {
      security_list_id = "ocid1.securitylist.oc1..mock"
    }
  }

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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "oci"
    error_message = "output.provider_type must be oci"
  }

  # --- OUTPUT: network_id is the OCI vcn id ---
  assert {
    condition     = output.network_id == "ocid1.vcn.oc1..mock"
    error_message = "output.network_id must equal the OCI vcn id"
  }

  # --- OUTPUT: subnet_id is the OCI subnet id ---
  assert {
    condition     = output.subnet_id == "ocid1.subnet.oc1..mock"
    error_message = "output.subnet_id must equal the OCI subnet id"
  }

  # --- OUTPUT: subnet_ids is the single-element OCI subnet list ---
  assert {
    condition     = toset(output.subnet_ids) == toset(["ocid1.subnet.oc1..mock"])
    error_message = "output.subnet_ids must equal the OCI subnet list"
  }

  # --- OUTPUT: security_group_id is the OCI security list id ---
  assert {
    condition     = output.security_group_id == "ocid1.securitylist.oc1..mock"
    error_message = "output.security_group_id must equal the OCI security list id"
  }

  # --- OUTPUT: vpc_cidr is the OCI vcn cidr ---
  assert {
    condition     = output.vpc_cidr == "10.100.0.0/16"
    error_message = "output.vpc_cidr must equal the OCI vcn cidr"
  }

  # --- OUTPUT: subnet_cidr is the OCI subnet cidr ---
  assert {
    condition     = output.subnet_cidr == "10.100.1.0/24"
    error_message = "output.subnet_cidr must equal the OCI subnet cidr"
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

  # --- OUTPUT: provider_type echoes the input ---
  assert {
    condition     = output.provider_type == "proxmox"
    error_message = "output.provider_type must be proxmox"
  }

  # --- OUTPUT: network_id is the bridge name from proxmox_config ---
  assert {
    condition     = output.network_id == "vmbr0"
    error_message = "output.network_id must be the configured bridge"
  }

  # --- OUTPUT: subnet_id is the bridge name (single-element list) ---
  assert {
    condition     = output.subnet_id == "vmbr0"
    error_message = "output.subnet_id must be the configured bridge"
  }

  # --- OUTPUT: subnet_ids is the bridge list ---
  assert {
    condition     = toset(output.subnet_ids) == toset(["vmbr0"])
    error_message = "output.subnet_ids must contain the configured bridge"
  }

  # --- OUTPUT: vpc_cidr defaults to proxmox network cidr ---
  assert {
    condition     = output.vpc_cidr == "192.168.68.0/24"
    error_message = "output.vpc_cidr must default to the proxmox network cidr"
  }

  # --- OUTPUT: subnet_cidr defaults to proxmox network cidr ---
  assert {
    condition     = output.subnet_cidr == "192.168.68.0/24"
    error_message = "output.subnet_cidr must default to the proxmox network cidr"
  }

  # --- OUTPUT: security_group_id is empty for proxmox ---
  assert {
    condition     = output.security_group_id == ""
    error_message = "output.security_group_id must be empty for proxmox"
  }

  # --- OUTPUT: proxmox raw output present, aws/oci null ---
  assert {
    condition     = output.proxmox != null && output.proxmox.network_bridge == "vmbr0"
    error_message = "output.proxmox must be set with the configured bridge"
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
