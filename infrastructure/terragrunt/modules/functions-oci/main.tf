# -----------------------------------------------------------------------------
# FUNCTIONS-OCI MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates one consumer's OCI Functions application, in a compartment of its
# own, with code-only functions zipped from the files given and a user whose
# API key can read and invoke them. Generic: it knows nothing about what the
# functions do, so a new consumer is a leaf and a catalog entry.
#
# Vault-free, matching kms-oci and code-engine: the private key is a sensitive
# output that the vault-secrets leaf writes.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# COMPARTMENT
#
# Functions policies accept only general conditions and cannot name one
# application, so the compartment is what bounds the consumer's key.
# -----------------------------------------------------------------------------

resource "oci_identity_compartment" "this" {
  compartment_id = var.tenancy_ocid
  name           = var.name
  description    = "OCI Functions that ${var.name} invokes"
  freeform_tags  = var.tags
}

# -----------------------------------------------------------------------------
# APPLICATION
# -----------------------------------------------------------------------------

resource "oci_functions_application" "this" {
  compartment_id = oci_identity_compartment.this.id
  display_name   = var.name
  subnet_ids     = var.subnet_ids
  shape          = var.shape
  freeform_tags  = var.tags
}

# -----------------------------------------------------------------------------
# FUNCTIONS
#
# Code-only: the files are zipped at their archive paths during plan and
# uploaded with the function, so no image or registry is involved. A fixed file
# mode keeps the archive byte-identical across runs, so only a change to the
# files updates it.
# -----------------------------------------------------------------------------

data "oci_functions_functions_runtime_versions" "this" {
  for_each = toset([for f in values(var.functions) : f.runtime])

  functions_runtime_name = each.key
  is_current_version     = true
}

data "archive_file" "this" {
  for_each = var.functions

  type             = "zip"
  output_file_mode = "0644"
  output_path      = "${path.module}/.terraform/archives/${each.key}.zip"

  dynamic "source" {
    for_each = each.value.files

    content {
      filename = source.key
      content  = source.value
    }
  }
}

resource "oci_functions_function" "this" {
  for_each = var.functions

  application_id     = oci_functions_application.this.id
  display_name       = each.key
  memory_in_mbs      = each.value.memory_in_mbs
  timeout_in_seconds = each.value.timeout_in_seconds
  freeform_tags      = var.tags

  source_details {
    source_type = "ARCHIVE"
    handler     = each.value.handler

    archive_source_details {
      archive_source_type = "DIRECT_ARCHIVE"
      archive_file        = filebase64(data.archive_file.this[each.key].output_path)
    }

    # --- the runtime moves to a newer version only when the function is updated ---
    runtime_config {
      functions_runtime_name       = each.value.runtime
      functions_runtime_version_id = data.oci_functions_functions_runtime_versions.this[each.value.runtime].functions_runtime_version_collection[0].items[0].id
      runtime_config_type          = "FUNCTION_UPDATE"
    }
  }
}

# -----------------------------------------------------------------------------
# INVOKING IDENTITY
#
# A user of its own rather than a personal key, which carries every permission
# its owner has. The RSA keypair backs its API key; the private half is what
# the consumer signs requests with.
# -----------------------------------------------------------------------------

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "oci_identity_user" "this" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name}-functions"
  description    = "Reads and invokes the functions in the ${var.name} compartment"
  email          = var.user_email
  freeform_tags  = var.tags
}

resource "oci_identity_group" "this" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name}-functions"
  description    = "Reads and invokes the functions in the ${var.name} compartment"
  freeform_tags  = var.tags
}

resource "oci_identity_user_group_membership" "this" {
  user_id  = oci_identity_user.this.id
  group_id = oci_identity_group.this.id
}

resource "oci_identity_api_key" "this" {
  user_id   = oci_identity_user.this.id
  key_value = tls_private_key.this.public_key_pem
}

# -----------------------------------------------------------------------------
# ACCESS POLICY
#
# Reading a function gives its invoke endpoint and memory; invoking runs it.
# Neither creates, changes nor deletes anything.
# -----------------------------------------------------------------------------

resource "oci_identity_policy" "this" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name}-functions"
  description    = "Read and invoke the functions in the ${var.name} compartment only"

  statements = [
    "Allow group ${oci_identity_group.this.name} to read fn-function in compartment id ${oci_identity_compartment.this.id}",
    "Allow group ${oci_identity_group.this.name} to use fn-invocation in compartment id ${oci_identity_compartment.this.id}",
  ]

  freeform_tags = var.tags
}
