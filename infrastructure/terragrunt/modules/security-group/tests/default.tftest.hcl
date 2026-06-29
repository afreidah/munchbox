# -----------------------------------------------------------------------------
# security-group module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts each preset rule (ssh, wireguard, icmp, trusted_tcp, trusted_udp)
# is independently gated by its var being non-null, the ingress_rules list
# fans out via for_each, and the trusted_cidr is reused across trusted_tcp +
# trusted_udp blocks.
# -----------------------------------------------------------------------------

mock_provider "aws" {
  # --- pin computed attrs so the SG outputs are known at plan time ---
  mock_resource "aws_security_group" {
    defaults = {
      id   = "sg-0123456789abcdef0"
      arn  = "arn:aws:ec2:us-east-1:123456789012:security-group/sg-0123456789abcdef0"
      name = "test-sg-mock"
    }
  }
}

variables {
  name        = "test-sg"
  description = "test security group"
  vpc_id      = "vpc-mock"
}

# -------------------------------------------------------------------------
# By default (all preset vars null), zero preset rules created
# -------------------------------------------------------------------------

run "no_presets_by_default" {
  command = plan

  # --- SSH preset count = 0 when allow_ssh is null ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 0
    error_message = "SSH preset must be off when allow_ssh is null"
  }

  # --- WireGuard preset count = 0 when allow_wireguard is null ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.wireguard) == 0
    error_message = "WireGuard preset must be off when allow_wireguard is null"
  }

  # --- ICMP preset count = 0 when allow_icmp is null ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.icmp) == 0
    error_message = "ICMP preset must be off when allow_icmp is null"
  }
}

# -------------------------------------------------------------------------
# SSH preset enabled with a CIDR -> exactly one rule on port 22
# -------------------------------------------------------------------------

run "ssh_preset_enabled" {
  command = plan

  variables {
    allow_ssh = "10.0.0.0/8"
  }

  # --- SSH rule count = 1 when allow_ssh is set ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 1
    error_message = "SSH rule should exist when allow_ssh is set"
  }

  # --- SSH rule targets port 22 ---
  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh[0].from_port == 22
    error_message = "SSH rule must target port 22"
  }

  # --- SSH cidr_ipv4 matches allow_ssh var ---
  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh[0].cidr_ipv4 == "10.0.0.0/8"
    error_message = "SSH cidr_ipv4 should match allow_ssh"
  }
}

# -------------------------------------------------------------------------
# WireGuard preset uses UDP/51820
# -------------------------------------------------------------------------

run "wireguard_preset_udp" {
  command = plan

  variables {
    allow_wireguard = "0.0.0.0/0"
  }

  # --- WireGuard rule must be UDP ---
  assert {
    condition     = aws_vpc_security_group_ingress_rule.wireguard[0].ip_protocol == "udp"
    error_message = "WireGuard rule must be UDP"
  }

  # --- WireGuard rule targets port 51820 ---
  assert {
    condition     = aws_vpc_security_group_ingress_rule.wireguard[0].from_port == 51820
    error_message = "WireGuard rule must target port 51820"
  }
}

# -------------------------------------------------------------------------
# trusted_cidr triggers both trusted_tcp + trusted_udp blanket rules
# -------------------------------------------------------------------------

run "trusted_cidr_dual_rules" {
  command = plan

  variables {
    trusted_cidr = "10.200.0.0/24"
  }

  # --- trusted_tcp rule count = 1 when trusted_cidr is set ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.trusted_tcp) == 1
    error_message = "trusted_cidr should create trusted_tcp rule"
  }

  # --- trusted_udp rule count = 1 when trusted_cidr is set ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.trusted_udp) == 1
    error_message = "trusted_cidr should create trusted_udp rule"
  }

  # --- trusted_tcp cidr_ipv4 propagates from trusted_cidr ---
  assert {
    condition     = aws_vpc_security_group_ingress_rule.trusted_tcp[0].cidr_ipv4 == "10.200.0.0/24"
    error_message = "trusted_tcp cidr must match trusted_cidr var"
  }
}

# -------------------------------------------------------------------------
# Custom ingress_rules list fans out via for_each
# -------------------------------------------------------------------------

run "custom_ingress_for_each" {
  command = plan

  variables {
    ingress_rules = [
      { from_port = 8080, to_port = 8080, protocol = "tcp", cidr = "10.0.0.0/8", description = "http" },
      { from_port = 8443, to_port = 8443, protocol = "tcp", cidr = "10.0.0.0/8", description = "https" },
    ]
    egress_rules = [
      { from_port = 0, to_port = 0, protocol = "-1", cidr = "0.0.0.0/0", description = "all out" },
    ]
  }

  # --- two ingress_rules entries -> two resources ---
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 2
    error_message = "ingress_rules list of two -> two resources"
  }

  # --- one egress_rules entry -> one egress resource ---
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 1
    error_message = "egress_rules list of one -> one egress resource"
  }

  # --- egress cidr_ipv4 propagates from the rule ---
  assert {
    condition     = aws_vpc_security_group_egress_rule.this["0"].cidr_ipv4 == "0.0.0.0/0"
    error_message = "egress cidr_ipv4 must propagate from egress_rules entry"
  }
}

# -------------------------------------------------------------------------
# SG itself uses create_before_destroy lifecycle (via name_prefix)
# -------------------------------------------------------------------------

run "sg_uses_create_before_destroy" {
  command = plan

  # --- name_prefix is set, enabling create_before_destroy renames ---
  assert {
    condition     = aws_security_group.this.name_prefix == "${var.name}-"
    error_message = "SG must use name_prefix to enable create_before_destroy renames"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: id/arn/name are computed resource attributes unknown until apply;
# the AWS mock_provider supplies them on apply so we can assert the wiring
# (mock_resource defaults below make the values deterministic).
# -------------------------------------------------------------------------

run "computed_outputs" {
  command = apply

  # --- security_group_id output surfaces aws_security_group.this.id ---
  assert {
    condition     = output.security_group_id == "sg-0123456789abcdef0"
    error_message = "security_group_id output must surface aws_security_group.this.id"
  }

  # --- security_group_arn output surfaces aws_security_group.this.arn ---
  assert {
    condition     = output.security_group_arn == "arn:aws:ec2:us-east-1:123456789012:security-group/sg-0123456789abcdef0"
    error_message = "security_group_arn output must surface aws_security_group.this.arn"
  }

  # --- security_group_name output surfaces aws_security_group.this.name ---
  assert {
    condition     = output.security_group_name == "test-sg-mock"
    error_message = "security_group_name output must surface aws_security_group.this.name"
  }
}
