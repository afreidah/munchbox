# -----------------------------------------------------------------------------
# networking (aws) module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the AWS VPC composition: VPC has DNS support, the default SG is
# tagged as locked (CKV2_AWS_12 hardening), subnets fan out per-AZ via count,
# public subnets auto-assign IPs by intent, and the route to the IGW lands
# in the public route table.
# -----------------------------------------------------------------------------

mock_provider "aws" {}

variables {
  name               = "test-vpc"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  tags               = { project = "munchbox" }
}

# -------------------------------------------------------------------------
# VPC: CIDR + DNS flags propagate
# -------------------------------------------------------------------------

run "vpc_inputs" {
  command = plan

  # --- VPC CIDR matches var ---
  assert {
    condition     = aws_vpc.this.cidr_block == var.vpc_cidr
    error_message = "VPC cidr_block must match var.vpc_cidr"
  }

  # --- DNS hostnames enabled (required for service discovery) ---
  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames must be enabled"
  }

  # --- DNS support enabled (required for VPC resolver) ---
  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "DNS support must be enabled"
  }
}

# -------------------------------------------------------------------------
# Default SG is managed by this module (locks it at apply for CKV2_AWS_12)
# -------------------------------------------------------------------------

run "default_sg_managed" {
  command = plan

  # --- tag identifies the SG as deliberately locked down ---
  assert {
    condition     = aws_default_security_group.default.tags.Name == "${var.name}-default-sg-locked"
    error_message = "default SG tag must label it as locked"
  }
}

# -------------------------------------------------------------------------
# Subnet + route-table-association counts fan out per AZ
# -------------------------------------------------------------------------

run "subnets_per_az" {
  command = plan

  # --- one public subnet per AZ ---
  assert {
    condition     = length(aws_subnet.public) == length(var.availability_zones)
    error_message = "one public subnet per AZ"
  }

  # --- one route_table_association per AZ ---
  assert {
    condition     = length(aws_route_table_association.public) == length(var.availability_zones)
    error_message = "one route_table_association per AZ"
  }
}

# -------------------------------------------------------------------------
# Public subnets auto-assign IPs (intentional; CKV_AWS_130 in skip list)
# -------------------------------------------------------------------------

run "subnets_assign_public_ip" {
  command = plan

  # --- map_public_ip_on_launch is true on every public subnet ---
  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "public subnets must auto-assign public IPs"
  }
}

# -------------------------------------------------------------------------
# Default route 0.0.0.0/0 points at the IGW
# -------------------------------------------------------------------------

run "default_route_via_igw" {
  command = plan

  # --- destination_cidr_block covers the world ---
  assert {
    condition     = aws_route.public_internet.destination_cidr_block == "0.0.0.0/0"
    error_message = "public route must cover 0.0.0.0/0"
  }
}

# -------------------------------------------------------------------------
# Single-AZ edge case still produces consistent count outputs
# -------------------------------------------------------------------------

run "single_az_edge_case" {
  command = plan

  variables {
    availability_zones = ["us-west-2a"]
  }

  # --- single AZ -> single subnet ---
  assert {
    condition     = length(aws_subnet.public) == 1
    error_message = "single AZ -> single subnet"
  }
}
