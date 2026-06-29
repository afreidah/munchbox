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

  # Pin computed spot-request attrs so outputs are known at plan time.
  mock_resource "aws_spot_instance_request" {
    defaults = {
      id                 = "sir-mock00000"
      spot_instance_id   = "i-mock00000000000"
      spot_request_state = "active"
      public_ip          = "203.0.113.20"
      private_ip         = "10.0.0.20"
      public_dns         = "ec2-203-0-113-20.compute.amazonaws.com"
      private_dns        = "ip-10-0-0-20.ec2.internal"
    }
  }

  mock_resource "aws_eip" {
    defaults = {
      public_ip = "203.0.113.30"
    }
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

# -------------------------------------------------------------------------
# OUTPUTS: default path (no EIP, ssh key created) covers most outputs
# -------------------------------------------------------------------------

run "outputs_default_path" {
  command = plan

  variables {
    ami_id         = "ami-explicitpinnedid0"
    ssh_public_key = "ssh-ed25519 AAAA test"
  }

  # --- ami_id honors explicit override ---
  assert {
    condition     = output.ami_id == "ami-explicitpinnedid0"
    error_message = "output.ami_id must equal explicit var.ami_id when set"
  }

  # --- key_name follows <name>-key convention when ssh_public_key set ---
  assert {
    condition     = output.key_name == "${var.name}-key"
    error_message = "output.key_name must follow <name>-key when ssh_public_key set"
  }

  # --- no EIP by default -> elastic_ip is null (plan-knowable literal) ---
  assert {
    condition     = output.elastic_ip == null
    error_message = "output.elastic_ip must be null when assign_elastic_ip = false"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: computed instance attrs are unknown until apply; mock_provider
# supplies them so we can assert the wiring (structure only, not value).
# -------------------------------------------------------------------------

run "outputs_computed_attrs" {
  command = apply

  variables {
    ssh_public_key = "ssh-ed25519 AAAA test"
  }

  # --- ssh_connection_string is the ssh ubuntu@<ip> form ---
  assert {
    condition     = startswith(output.ssh_connection_string, "ssh ubuntu@")
    error_message = "output.ssh_connection_string must start with 'ssh ubuntu@'"
  }

  # --- computed attrs (mock-provided): structure only ---
  assert {
    condition     = output.spot_request_id != null
    error_message = "output.spot_request_id must be non-null"
  }

  assert {
    condition     = output.spot_instance_id != null
    error_message = "output.spot_instance_id must be non-null"
  }

  assert {
    condition     = output.spot_request_state != null
    error_message = "output.spot_request_state must be non-null"
  }

  assert {
    condition     = output.public_ip != null
    error_message = "output.public_ip must be non-null"
  }

  assert {
    condition     = output.private_ip != null
    error_message = "output.private_ip must be non-null"
  }

  assert {
    condition     = output.public_dns != null
    error_message = "output.public_dns must be non-null"
  }

  assert {
    condition     = output.private_dns != null
    error_message = "output.private_dns must be non-null"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: key_name falls back to var.key_name when no ssh_public_key
# -------------------------------------------------------------------------

run "output_key_name_fallback" {
  command = plan

  variables {
    ssh_public_key = null
    key_name       = "preexisting-key"
  }

  # --- key_name passes through var.key_name when no SSH key managed ---
  assert {
    condition     = output.key_name == "preexisting-key"
    error_message = "output.key_name must fall back to var.key_name when ssh_public_key is null"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: EIP path -> elastic_ip non-null
# -------------------------------------------------------------------------

run "outputs_eip_path" {
  command = apply

  variables {
    assign_elastic_ip = true
  }

  # --- elastic_ip is populated from the managed EIP (computed) ---
  assert {
    condition     = output.elastic_ip != null
    error_message = "output.elastic_ip must be non-null when assign_elastic_ip = true"
  }
}
