# -----------------------------------------------------------------------------
# SECURITY GROUP MODULE - PRESET RULES
# -----------------------------------------------------------------------------
#
# Common preset rules for homelab use cases. These are created conditionally
# based on the preset variables (allow_ssh, allow_wireguard, etc.)
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SSH PRESET
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count = var.allow_ssh != null ? 1 : 0

  security_group_id = aws_security_group.this.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allow_ssh
  description       = "SSH access"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# WIREGUARD PRESET
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  count = var.allow_wireguard != null ? 1 : 0

  security_group_id = aws_security_group.this.id
  from_port         = 51820
  to_port           = 51820
  ip_protocol       = "udp"
  cidr_ipv4         = var.allow_wireguard
  description       = "WireGuard VPN"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# ICMP PRESET
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  count = var.allow_icmp != null ? 1 : 0

  security_group_id = aws_security_group.this.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = var.allow_icmp
  description       = "ICMP (ping)"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# TRUSTED NETWORK PRESET (ALL TCP/UDP)
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "trusted_tcp" {
  count = var.trusted_cidr != null ? 1 : 0

  security_group_id = aws_security_group.this.id
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = var.trusted_cidr
  description       = "All TCP from trusted network"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "trusted_udp" {
  count = var.trusted_cidr != null ? 1 : 0

  security_group_id = aws_security_group.this.id
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "udp"
  cidr_ipv4         = var.trusted_cidr
  description       = "All UDP from trusted network"

  tags = var.tags
}
