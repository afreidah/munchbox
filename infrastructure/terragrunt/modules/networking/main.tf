# -----------------------------------------------------------------------------
# NETWORKING MODULE
# -----------------------------------------------------------------------------
#
# Simple VPC networking for homelab cloud deployments. Designed for cost
# efficiency - uses public subnets only (no NAT Gateway costs).
#
# Components Created:
#   - VPC with DNS support
#   - Internet Gateway
#   - Public subnet(s) across availability zones
#   - Route table with internet access
#
# Use Case:
#   - Spot instances with public IPs
#   - WireGuard VPN endpoints
#   - Cost-conscious cloud extensions to homelab
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

# --- lock down the auto-created default SG (CKV2_AWS_12); no ingress/egress rules ---
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default-sg-locked"
  })
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNETS
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# ROUTE TABLE
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
