# -----------------------------------------------------------------------------
# COMPUTE MODULE - ORACLE CLOUD
# -----------------------------------------------------------------------------
#
# Provisions OCI compute instances. Supports both fixed shapes (AMD micro)
# and flexible shapes (ARM Ampere A1).
#
# Features:
#   - Automatic AMI lookup for Ubuntu 24.04
#   - Support for AMD (E2.1.Micro) and ARM (A1.Flex) shapes
#   - Flexible OCPU/memory configuration for ARM instances
#   - User data for bootstrapping
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# DATA SOURCES - AVAILABILITY DOMAINS
# -----------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

locals {
  # Support both full AD name and short forms like "AD-1", "1", etc.
  ad_index = can(regex("^\\d+$", var.availability_domain)) ? tonumber(var.availability_domain) - 1 : (
    can(regex("^AD-\\d+$", var.availability_domain)) ? tonumber(replace(var.availability_domain, "AD-", "")) - 1 : null
  )
  availability_domain = local.ad_index != null ? data.oci_identity_availability_domains.ads.availability_domains[local.ad_index].name : var.availability_domain
}

# -----------------------------------------------------------------------------
# DATA SOURCES - IMAGE LOOKUP
# -----------------------------------------------------------------------------

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = var.ubuntu_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# -----------------------------------------------------------------------------
# COMPUTE INSTANCE
# -----------------------------------------------------------------------------

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = var.name
  shape               = var.shape

  # Shape config only for flexible shapes (ARM A1)
  dynamic "shape_config" {
    for_each = var.ocpus != null ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_gb
    }
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id != null ? var.image_id : data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    display_name     = "${var.name}-vnic"
    assign_public_ip = var.assign_public_ip
    hostname_label   = var.hostname_label != null ? var.hostname_label : replace(var.name, "/[^a-z0-9]/", "")
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = var.user_data != null ? base64encode(var.user_data) : null
  }

  lifecycle {
    prevent_destroy = false

    # --- Don't replace a running node when Oracle bumps the "latest ubuntu"
    #     image OCID or when seed metadata (ssh keys / user_data) is edited
    #     post-bootstrap. Both fields force replacement; the live config of a
    #     running node is owned by chef (sshd_ca for keys, recipes for the
    #     rest), so cloud-init drift after the first converge is noise. ---
    ignore_changes = [
      source_details,
      metadata,
    ]
  }
}
