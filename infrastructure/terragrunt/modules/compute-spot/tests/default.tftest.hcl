# -----------------------------------------------------------------------------
# compute-spot module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the AMI-source switch (arm64 vs x86_64 data sources gated by
# count), the ssh_public_key -> aws_key_pair conditional, the EIP +
# association conditional gating, and that root volume is always encrypted.
# -----------------------------------------------------------------------------

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-mockmockmockmockm" }
  }
}

variables {
  name               = "test-spot"
  subnet_id          = "subnet-mock"
  security_group_ids = ["sg-mock"]
  instance_type      = "t4g.medium"
  architecture       = "arm64"
  root_volume_size   = 20
}

# -------------------------------------------------------------------------
# arm64 architecture fires arm AMI data source, x86 skipped
# -------------------------------------------------------------------------

run "arm64_uses_arm_ami_lookup" {
  command = plan

  # --- ubuntu_arm data lookup count = 1 for arm64 ---
  assert {
    condition     = length(data.aws_ami.ubuntu_arm) == 1
    error_message = "arm64 architecture should trigger ubuntu_arm data lookup"
  }

  # --- ubuntu_x86 data lookup count = 0 for arm64 ---
  assert {
    condition     = length(data.aws_ami.ubuntu_x86) == 0
    error_message = "arm64 architecture should NOT trigger ubuntu_x86 data lookup"
  }
}

# -------------------------------------------------------------------------
# x86_64 architecture flips the AMI-source gating
# -------------------------------------------------------------------------

run "x86_uses_x86_ami_lookup" {
  command = plan

  variables {
    architecture  = "x86_64"
    instance_type = "t3.medium"
  }

  # --- ubuntu_arm data lookup count = 0 for x86_64 ---
  assert {
    condition     = length(data.aws_ami.ubuntu_arm) == 0
    error_message = "x86_64 should NOT trigger arm AMI lookup"
  }

  # --- ubuntu_x86 data lookup count = 1 for x86_64 ---
  assert {
    condition     = length(data.aws_ami.ubuntu_x86) == 1
    error_message = "x86_64 should trigger x86 AMI lookup"
  }
}

# -------------------------------------------------------------------------
# ssh_public_key null -> no aws_key_pair resource
# -------------------------------------------------------------------------

run "no_key_when_unset" {
  command = plan

  variables {
    ssh_public_key = null
    key_name       = "preexisting-key"
  }

  # --- aws_key_pair count = 0 when no SSH key provided ---
  assert {
    condition     = length(aws_key_pair.this) == 0
    error_message = "no aws_key_pair when ssh_public_key is null"
  }
}

# -------------------------------------------------------------------------
# ssh_public_key set -> aws_key_pair created with <name>-key convention
# -------------------------------------------------------------------------

run "key_created_when_set" {
  command = plan

  variables {
    ssh_public_key = "ssh-ed25519 AAAA test"
  }

  # --- aws_key_pair count = 1 when SSH key provided ---
  assert {
    condition     = length(aws_key_pair.this) == 1
    error_message = "aws_key_pair should be created when ssh_public_key is set"
  }

  # --- key_name follows <var.name>-key convention ---
  assert {
    condition     = aws_key_pair.this[0].key_name == "${var.name}-key"
    error_message = "key_pair name must follow <var.name>-key convention"
  }
}

# -------------------------------------------------------------------------
# assign_elastic_ip = false -> no EIP, no association
# -------------------------------------------------------------------------

run "no_eip_by_default" {
  command = plan

  # --- EIP count = 0 by default ---
  assert {
    condition     = length(aws_eip.this) == 0
    error_message = "no EIP when assign_elastic_ip = false"
  }

  # --- EIP association count = 0 by default ---
  assert {
    condition     = length(aws_eip_association.this) == 0
    error_message = "no EIP association when assign_elastic_ip = false"
  }
}

# -------------------------------------------------------------------------
# assign_elastic_ip = true -> both EIP + association created
# -------------------------------------------------------------------------

run "eip_created_when_enabled" {
  command = plan

  variables {
    assign_elastic_ip = true
  }

  # --- EIP count = 1 when enabled ---
  assert {
    condition     = length(aws_eip.this) == 1
    error_message = "EIP should be created when assign_elastic_ip = true"
  }

  # --- EIP association count = 1 when enabled ---
  assert {
    condition     = length(aws_eip_association.this) == 1
    error_message = "EIP association should be created when assign_elastic_ip = true"
  }
}

# -------------------------------------------------------------------------
# Root volume is always encrypted (hardening default)
# -------------------------------------------------------------------------

run "root_volume_encrypted_default" {
  command = plan

  # --- root_block_device.encrypted = true by default ---
  assert {
    condition     = aws_spot_instance_request.this.root_block_device[0].encrypted == true
    error_message = "root volume must be encrypted by default"
  }
}
