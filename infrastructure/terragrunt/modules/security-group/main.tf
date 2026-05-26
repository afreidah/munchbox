# -----------------------------------------------------------------------------
# SECURITY GROUP MODULE
# -----------------------------------------------------------------------------
#
# Flexible security group with configurable ingress/egress rules.
# Supports common homelab patterns like WireGuard, SSH, and Nomad ports.
#
# Features:
#   - Configurable ingress/egress rules via variables
#   - Built-in presets for common services (wireguard, ssh, nomad, consul)
#   - Create-before-destroy lifecycle for safe updates
#   - Support for trusted CIDR ranges (e.g., WireGuard subnet)
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SECURITY GROUP
# -----------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# INGRESS RULES
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr
  description       = each.value.description

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EGRESS RULES
# -----------------------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr
  description       = each.value.description

  tags = var.tags
}
