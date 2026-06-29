# -----------------------------------------------------------------------------
# block-volume-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the volumes-list-to-map composition: the input list flattens into
# a name-keyed map, every volume gets a paired attachment, size/vpus
# propagate per-volume, and attachment display_name follows the
# <volume>-attachment convention.
# -----------------------------------------------------------------------------

mock_provider "oci" {}

variables {
  compartment_id      = "ocid1.compartment.oc1..mock"
  availability_domain = "AD-1"
  instance_id         = "ocid1.instance.oc1..mock"
  volumes = [
    { name = "minio-data", size_gb = 80, vpus_per_gb = 10, attachment_type = "paravirtualized" },
    { name = "logs", size_gb = 50, vpus_per_gb = 0, attachment_type = "iscsi" },
  ]
  tags = { project = "munchbox" }
}

# -------------------------------------------------------------------------
# Input list flattens into a name-keyed map
# -------------------------------------------------------------------------

run "volumes_keyed_by_name" {
  command = plan

  # --- two input entries -> two resources ---
  assert {
    condition     = length(oci_core_volume.this) == 2
    error_message = "two input volumes should produce two volume resources"
  }

  # --- 'minio-data' key exists in the for_each map ---
  assert {
    condition     = contains(keys(oci_core_volume.this), "minio-data")
    error_message = "volume 'minio-data' should exist in the map"
  }

  # --- 'logs' key exists in the for_each map ---
  assert {
    condition     = contains(keys(oci_core_volume.this), "logs")
    error_message = "volume 'logs' should exist in the map"
  }
}

# -------------------------------------------------------------------------
# Per-volume size + vpus pass through
# -------------------------------------------------------------------------

run "size_and_vpus_propagate" {
  command = plan

  # --- minio-data size matches input ---
  assert {
    condition     = tonumber(oci_core_volume.this["minio-data"].size_in_gbs) == 80
    error_message = "minio-data size should be 80GB"
  }

  # --- logs vpus_per_gb = 0 (cold tier) propagates ---
  assert {
    condition     = tonumber(oci_core_volume.this["logs"].vpus_per_gb) == 0
    error_message = "logs vpus_per_gb should be 0 (cold tier)"
  }
}

# -------------------------------------------------------------------------
# One attachment per volume; attachment_type comes from input
# -------------------------------------------------------------------------

run "attachment_per_volume" {
  command = plan

  # --- attachments map has same cardinality as volumes map ---
  assert {
    condition     = length(oci_core_volume_attachment.this) == 2
    error_message = "one attachment per volume"
  }

  # --- minio-data uses paravirtualized attachment ---
  assert {
    condition     = oci_core_volume_attachment.this["minio-data"].attachment_type == "paravirtualized"
    error_message = "minio-data attachment_type should be paravirtualized"
  }

  # --- logs uses iscsi attachment ---
  assert {
    condition     = oci_core_volume_attachment.this["logs"].attachment_type == "iscsi"
    error_message = "logs attachment_type should be iscsi"
  }
}

# -------------------------------------------------------------------------
# Attachment display_name follows <volume>-attachment convention
# -------------------------------------------------------------------------

run "attachment_display_name_convention" {
  command = plan

  # --- name template is <volume>-attachment ---
  assert {
    condition     = oci_core_volume_attachment.this["minio-data"].display_name == "minio-data-attachment"
    error_message = "attachment display_name must follow <volume>-attachment convention"
  }
}

# -------------------------------------------------------------------------
# Empty volumes list edge case: zero resources
# -------------------------------------------------------------------------

run "empty_volumes_list" {
  command = plan

  variables {
    volumes = []
  }

  # --- empty list -> zero volume resources ---
  assert {
    condition     = length(oci_core_volume.this) == 0
    error_message = "empty volumes list should produce zero resources"
  }

  # --- empty input yields an empty volumes output map ---
  assert {
    condition     = length(output.volumes) == 0
    error_message = "output.volumes must be empty for an empty volumes list"
  }

  # --- empty input yields an empty attachments output map ---
  assert {
    condition     = length(output.attachments) == 0
    error_message = "output.attachments must be empty for an empty volumes list"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- make the computed ids known during plan so the map outputs resolve ---
  override_resource {
    target          = oci_core_volume.this["minio-data"]
    override_during = plan
    values          = { id = "ocid1.volume.oc1..mock" }
  }
  override_resource {
    target          = oci_core_volume_attachment.this["minio-data"]
    override_during = plan
    values          = { id = "ocid1.volumeattachment.oc1..mock" }
  }

  # --- volumes output keyed by volume name ---
  assert {
    condition     = toset(keys(output.volumes)) == toset(["minio-data", "logs"])
    error_message = "output.volumes must be keyed by volume name"
  }

  # --- per-volume size_gb is preserved in the volumes output ---
  assert {
    condition     = tonumber(output.volumes["minio-data"].size_gb) == 80
    error_message = "output.volumes[minio-data].size_gb must be 80"
  }

  # --- volumes output carries the computed volume id (mocked) ---
  assert {
    condition     = output.volumes["minio-data"].id == "ocid1.volume.oc1..mock"
    error_message = "output.volumes[minio-data].id must be the volume ocid"
  }

  # --- attachments output keyed by volume name ---
  assert {
    condition     = toset(keys(output.attachments)) == toset(["minio-data", "logs"])
    error_message = "output.attachments must be keyed by volume name"
  }

  # --- attachments output carries the computed attachment id (mocked) ---
  assert {
    condition     = output.attachments["minio-data"].id == "ocid1.volumeattachment.oc1..mock"
    error_message = "output.attachments[minio-data].id must be the attachment ocid"
  }
}
