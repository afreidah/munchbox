# -----------------------------------------------------------------------------
# compute-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the OCI instance composition: shape_config dynamic block only fires
# when ocpus != null (flexible-shape case), the hardening fields are pinned
# (is_pv_encryption_in_transit_enabled, instance_options legacy IMDS off),
# image_id var overrides the data-source lookup, and the AD-index parser
# handles both numeric and "AD-N" forms.
# -----------------------------------------------------------------------------

mock_provider "oci" {
  mock_data "oci_identity_availability_domains" {
    defaults = {
      availability_domains = [
        { name = "MockAD-1" },
        { name = "MockAD-2" },
      ]
    }
  }

  mock_data "oci_core_images" {
    defaults = {
      images = [{ id = "ocid1.image.oc1..mock-latest-ubuntu" }]
    }
  }
}

variables {
  name                = "test-instance"
  compartment_id      = "ocid1.compartment.oc1..mock"
  availability_domain = "1"
  subnet_id           = "ocid1.subnet.oc1..mock"
  ssh_public_key      = "ssh-ed25519 AAAA test"
  ubuntu_version      = "24.04"
}

# -------------------------------------------------------------------------
# Security hardening pinned (CKV_OCI_4 + CKV_OCI_5)
# -------------------------------------------------------------------------

run "hardening_pinned" {
  command = plan

  # --- in-transit encryption between hypervisor and boot volume ---
  assert {
    condition     = oci_core_instance.this.is_pv_encryption_in_transit_enabled == true
    error_message = "is_pv_encryption_in_transit_enabled must be true (CKV_OCI_4)"
  }

  # --- legacy IMDS endpoint disabled (IMDSv2-only) ---
  assert {
    condition     = oci_core_instance.this.instance_options[0].are_legacy_imds_endpoints_disabled == true
    error_message = "legacy IMDS must be disabled (CKV_OCI_5)"
  }
}

# -------------------------------------------------------------------------
# shape_config dynamic block skipped for fixed shapes (ocpus = null)
# -------------------------------------------------------------------------

run "shape_config_skipped_when_fixed" {
  command = plan

  variables {
    shape = "VM.Standard.E2.1.Micro"
    ocpus = null
  }

  # --- no shape_config block for fixed shapes ---
  assert {
    condition     = length(oci_core_instance.this.shape_config) == 0
    error_message = "shape_config block must NOT render for fixed shapes (ocpus = null)"
  }
}

# -------------------------------------------------------------------------
# shape_config dynamic block renders for flexible shapes (ocpus set)
# -------------------------------------------------------------------------

run "shape_config_renders_when_flex" {
  command = plan

  variables {
    shape     = "VM.Standard.A1.Flex"
    ocpus     = 2
    memory_gb = 12
  }

  # --- shape_config block exists when ocpus is set ---
  assert {
    condition     = length(oci_core_instance.this.shape_config) == 1
    error_message = "shape_config block must render when ocpus is set"
  }

  # --- ocpus var propagates into the dynamic block ---
  assert {
    condition     = oci_core_instance.this.shape_config[0].ocpus == 2
    error_message = "shape_config ocpus must propagate"
  }
}

# -------------------------------------------------------------------------
# Explicit image_id overrides the latest-ubuntu data-source lookup
# -------------------------------------------------------------------------

run "explicit_image_id_overrides_data_lookup" {
  command = plan

  variables {
    image_id = "ocid1.image.oc1..my-pinned-image"
  }

  # --- source_id matches the explicit override ---
  assert {
    condition     = oci_core_instance.this.source_details[0].source_id == "ocid1.image.oc1..my-pinned-image"
    error_message = "explicit image_id must override the data-source result"
  }
}

# -------------------------------------------------------------------------
# AD parser: numeric form ("1") resolves to availability_domains[0].name
# -------------------------------------------------------------------------

run "ad_parser_numeric" {
  command = plan

  variables {
    availability_domain = "1"
  }

  # --- "1" looks up domains[0] which mock returns as MockAD-1 ---
  assert {
    condition     = oci_core_instance.this.availability_domain == "MockAD-1"
    error_message = "AD parser must convert \"1\" to availability_domains[0].name"
  }
}

# -------------------------------------------------------------------------
# AD parser: "AD-N" form resolves to availability_domains[N-1].name
# -------------------------------------------------------------------------

run "ad_parser_ad_prefix" {
  command = plan

  variables {
    availability_domain = "AD-2"
  }

  # --- "AD-2" looks up domains[1] which mock returns as MockAD-2 ---
  assert {
    condition     = oci_core_instance.this.availability_domain == "MockAD-2"
    error_message = "AD parser must convert \"AD-2\" to availability_domains[1].name"
  }
}

# -------------------------------------------------------------------------
# AD parser: full AD name passes through unchanged
# -------------------------------------------------------------------------

run "ad_parser_passthrough" {
  command = plan

  variables {
    availability_domain = "literally-the-full-ad-name"
  }

  # --- non-numeric, non-AD-prefix strings pass through unchanged ---
  assert {
    condition     = oci_core_instance.this.availability_domain == "literally-the-full-ad-name"
    error_message = "AD parser must pass through full names unchanged"
  }
}
