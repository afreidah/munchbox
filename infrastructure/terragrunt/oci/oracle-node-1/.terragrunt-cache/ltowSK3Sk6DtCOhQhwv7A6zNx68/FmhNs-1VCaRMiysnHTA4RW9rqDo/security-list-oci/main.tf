# -----------------------------------------------------------------------------
# SECURITY LIST MODULE - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# Flexible security list with configurable ingress/egress rules.
# OCI security lists attach to subnets (unlike AWS security groups on instances).
#
# Features:
#   - Configurable ingress/egress rules via variables
#   - Built-in presets for common services (wireguard, ssh, icmp)
#   - Support for trusted CIDR ranges
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SECURITY LIST
# -----------------------------------------------------------------------------

resource "oci_core_security_list" "this" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = var.name

  # Default egress: Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
    description = "Allow all outbound"
  }

  # Dynamic ingress rules from variable
  dynamic "ingress_security_rules" {
    for_each = var.ingress_rules
    content {
      protocol    = ingress_security_rules.value.protocol
      source      = ingress_security_rules.value.source
      stateless   = false
      description = ingress_security_rules.value.description

      dynamic "tcp_options" {
        for_each = ingress_security_rules.value.protocol == "6" && ingress_security_rules.value.port_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.port_min
          max = ingress_security_rules.value.port_max
        }
      }

      dynamic "udp_options" {
        for_each = ingress_security_rules.value.protocol == "17" && ingress_security_rules.value.port_min != null ? [1] : []
        content {
          min = ingress_security_rules.value.port_min
          max = ingress_security_rules.value.port_max
        }
      }
    }
  }

  # Preset: SSH
  dynamic "ingress_security_rules" {
    for_each = var.allow_ssh != null ? [1] : []
    content {
      protocol    = "6" # TCP
      source      = var.allow_ssh
      stateless   = false
      description = "SSH"
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # Preset: WireGuard
  dynamic "ingress_security_rules" {
    for_each = var.allow_wireguard != null ? [1] : []
    content {
      protocol    = "17" # UDP
      source      = var.allow_wireguard
      stateless   = false
      description = "WireGuard"
      udp_options {
        min = 51820
        max = 51820
      }
    }
  }

  # Preset: ICMP
  dynamic "ingress_security_rules" {
    for_each = var.allow_icmp != null ? [1] : []
    content {
      protocol    = "1" # ICMP
      source      = var.allow_icmp
      stateless   = false
      description = "ICMP (ping)"
    }
  }

  # Preset: Trusted CIDR (all TCP)
  dynamic "ingress_security_rules" {
    for_each = var.trusted_cidr != null ? [1] : []
    content {
      protocol    = "6" # TCP
      source      = var.trusted_cidr
      stateless   = false
      description = "All TCP from trusted network"
    }
  }

  # Preset: Trusted CIDR (all UDP)
  dynamic "ingress_security_rules" {
    for_each = var.trusted_cidr != null ? [1] : []
    content {
      protocol    = "17" # UDP
      source      = var.trusted_cidr
      stateless   = false
      description = "All UDP from trusted network"
    }
  }
}
