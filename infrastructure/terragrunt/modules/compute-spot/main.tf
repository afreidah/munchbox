# -----------------------------------------------------------------------------
# COMPUTE SPOT MODULE
# -----------------------------------------------------------------------------
#
# Cost-effective spot instances for homelab cloud extensions.
# Supports both ARM (Graviton) and x86 instance types.
#
# Features:
#   - Persistent spot requests (stop on interruption, not terminate)
#   - Automatic AMI lookup for Ubuntu 24.04
#   - Encrypted root volumes
#   - SSH key management
#   - Support for user_data scripts
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DATA SOURCES - AMI LOOKUP
# -----------------------------------------------------------------------------

# Ubuntu 24.04 ARM AMI
data "aws_ami" "ubuntu_arm" {
  count       = var.architecture == "arm64" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Ubuntu 24.04 x86 AMI
data "aws_ami" "ubuntu_x86" {
  count       = var.architecture == "x86_64" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.architecture == "arm64" ? data.aws_ami.ubuntu_arm[0].id : data.aws_ami.ubuntu_x86[0].id
}

# -----------------------------------------------------------------------------
# SSH KEY
# -----------------------------------------------------------------------------

resource "aws_key_pair" "this" {
  count = var.ssh_public_key != null ? 1 : 0

  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key

  tags = merge(var.tags, {
    Name = "${var.name}-key"
  })
}

# -----------------------------------------------------------------------------
# SPOT INSTANCE REQUEST
# -----------------------------------------------------------------------------

resource "aws_spot_instance_request" "this" {
  ami                    = var.ami_id != null ? var.ami_id : local.ami_id
  instance_type          = var.instance_type
  key_name               = var.ssh_public_key != null ? aws_key_pair.this[0].key_name : var.key_name
  vpc_security_group_ids = var.security_group_ids
  subnet_id              = var.subnet_id

  # Spot configuration
  spot_type                      = var.spot_type
  instance_interruption_behavior = var.interruption_behavior
  wait_for_fulfillment           = var.wait_for_fulfillment

  # Root volume
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = var.encrypt_root_volume
  }

  # User data for bootstrapping
  user_data = var.user_data

  tags = merge(var.tags, {
    Name = var.name
  })
}

# -----------------------------------------------------------------------------
# ELASTIC IP (OPTIONAL)
# -----------------------------------------------------------------------------

resource "aws_eip" "this" {
  count  = var.assign_elastic_ip ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-eip"
  })
}

resource "aws_eip_association" "this" {
  count         = var.assign_elastic_ip ? 1 : 0
  instance_id   = aws_spot_instance_request.this.spot_instance_id
  allocation_id = aws_eip.this[0].id

  depends_on = [aws_spot_instance_request.this]
}
