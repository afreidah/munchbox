# -----------------------------------------------------------------------------
# functions-oci module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts what makes the credential safe to hand out and the functions
# deployable: one compartment, application, user and policy per consumer; the
# policy reading and invoking that compartment's functions only; each function
# built from its source directory as a code-only archive; and vault_data
# carrying the key alongside the coordinates it is useless without.
# -----------------------------------------------------------------------------

# --- the current runtime version is a nested collection the mock must shape ---
mock_provider "oci" {
  mock_data "oci_functions_functions_runtime_versions" {
    defaults = {
      functions_runtime_version_collection = [{ items = [{ id = "ocid1.fnruntimeversion.oc1.phx.mock" }] }]
    }
  }
}

mock_provider "tls" {}

# --- archive runs for real: plan reads the zip it writes, which a mock never does ---

variables {
  tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  region       = "us-phoenix-1"
  subnet_ids   = ["ocid1.subnet.oc1.phx.mock"]
  name         = "vagabond"
  user_email   = "functions@example.com"
  tags         = { Project = "munchbox" }

  functions = {
    livetest = {
      files   = { "function/func.py" = "def handler(ctx, data=None):\n    return None\n" }
      runtime = "python312.ol9"
      handler = "func.handler"
    }
  }
}

# -------------------------------------------------------------------------
# Naming: the compartment, application and identities carry the consumer
# -------------------------------------------------------------------------

run "naming" {
  command = plan

  # --- compartment and application named for the consumer ---
  assert {
    condition     = oci_identity_compartment.this.name == "vagabond" && oci_functions_application.this.display_name == "vagabond"
    error_message = "compartment and application must be named for the consumer"
  }

  # --- identities named <name>-functions so a tenancy listing is readable ---
  assert {
    condition     = oci_identity_user.this.name == "vagabond-functions" && oci_identity_group.this.name == "vagabond-functions" && oci_identity_policy.this.name == "vagabond-functions"
    error_message = "user, group and policy must be named <name>-functions"
  }

  # --- one function per entry, keeping its own name within the application ---
  assert {
    condition     = length(oci_functions_function.this) == 1 && oci_functions_function.this["livetest"].display_name == "livetest"
    error_message = "one function per entry, named for its key"
  }
}

# -------------------------------------------------------------------------
# The user is in the group the policy names, so the policy reaches its key
# -------------------------------------------------------------------------

run "membership_binds_user_to_group" {
  command = plan

  override_resource {
    target          = oci_identity_user.this
    override_during = plan
    values          = { id = "ocid1.user.oc1..vagabond" }
  }
  override_resource {
    target          = oci_identity_group.this
    override_during = plan
    values          = { id = "ocid1.group.oc1..vagabond" }
  }

  assert {
    condition     = oci_identity_user_group_membership.this.user_id == "ocid1.user.oc1..vagabond" && oci_identity_user_group_membership.this.group_id == "ocid1.group.oc1..vagabond"
    error_message = "the membership must put the invoking user in the policy's group"
  }
}

# -------------------------------------------------------------------------
# Least privilege: read and invoke, in the consumer's compartment only
# -------------------------------------------------------------------------

run "policy_is_least_privilege" {
  command = plan

  override_resource {
    target          = oci_identity_compartment.this
    override_during = plan
    values          = { id = "ocid1.compartment.oc1..vagabond" }
  }

  # --- reading a function gives its endpoint and memory, nothing more ---
  assert {
    condition     = contains(oci_identity_policy.this.statements, "Allow group vagabond-functions to read fn-function in compartment id ocid1.compartment.oc1..vagabond")
    error_message = "policy must grant read fn-function in the consumer's compartment"
  }

  # --- invoking runs a function and changes nothing ---
  assert {
    condition     = contains(oci_identity_policy.this.statements, "Allow group vagabond-functions to use fn-invocation in compartment id ocid1.compartment.oc1..vagabond")
    error_message = "policy must grant use fn-invocation in the consumer's compartment"
  }

  # --- and nothing else ---
  assert {
    condition     = length(oci_identity_policy.this.statements) == 2
    error_message = "policy must hold exactly the read and invoke statements"
  }
}

# -------------------------------------------------------------------------
# Functions are code-only archives on a managed runtime
# -------------------------------------------------------------------------

run "function_is_code_only" {
  command = plan

  # --- the files uploaded as the archive ---
  assert {
    condition     = oci_functions_function.this["livetest"].source_details[0].source_type == "ARCHIVE"
    error_message = "function must be created from an archive"
  }

  assert {
    condition     = oci_functions_function.this["livetest"].source_details[0].archive_source_details[0].archive_source_type == "DIRECT_ARCHIVE"
    error_message = "archive must be uploaded with the function"
  }

  assert {
    condition     = length(oci_functions_function.this["livetest"].source_details[0].archive_source_details[0].archive_file) > 0
    error_message = "archive must carry the zipped files"
  }

  # --- the runtime and handler from the entry, at the current version ---
  assert {
    condition     = oci_functions_function.this["livetest"].source_details[0].runtime_config[0].functions_runtime_name == "python312.ol9" && oci_functions_function.this["livetest"].source_details[0].handler == "func.handler"
    error_message = "runtime and handler must come from the function entry"
  }

  assert {
    condition     = oci_functions_function.this["livetest"].source_details[0].runtime_config[0].functions_runtime_version_id == "ocid1.fnruntimeversion.oc1.phx.mock"
    error_message = "runtime version must be the runtime's current version"
  }

  # --- a newer runtime version arrives only with a function update ---
  assert {
    condition     = oci_functions_function.this["livetest"].source_details[0].runtime_config[0].runtime_config_type == "FUNCTION_UPDATE"
    error_message = "runtime config must follow function updates"
  }
}

# -------------------------------------------------------------------------
# Defaults: x86, the smallest memory and the 30 second timeout
# -------------------------------------------------------------------------

run "defaults" {
  command = plan

  assert {
    condition     = oci_functions_application.this.shape == "GENERIC_X86"
    error_message = "shape must default to GENERIC_X86"
  }

  assert {
    condition     = tostring(oci_functions_function.this["livetest"].memory_in_mbs) == "128" && oci_functions_function.this["livetest"].timeout_in_seconds == 30
    error_message = "memory and timeout must default to 128 MB and 30 seconds"
  }
}

# -------------------------------------------------------------------------
# A consumer without functions still gets its application and identity
# -------------------------------------------------------------------------

run "no_functions" {
  command = plan

  variables {
    functions = {}
  }

  assert {
    condition     = length(oci_functions_function.this) == 0 && oci_identity_user.this.name == "vagabond-functions"
    error_message = "no functions must still create the application and identity"
  }
}

# -------------------------------------------------------------------------
# Validation: shape, memory and timeout outside what OCI accepts
# -------------------------------------------------------------------------

run "rejects_unknown_shape" {
  command = plan

  variables {
    shape = "GENERIC_RISCV"
  }

  expect_failures = [var.shape]
}

run "rejects_empty_archive" {
  command = plan

  variables {
    functions = { livetest = { files = {}, runtime = "python312.ol9" } }
  }

  expect_failures = [var.functions]
}

run "rejects_unsupported_memory" {
  command = plan

  variables {
    functions = { livetest = { files = { "function/func.py" = "" }, runtime = "python312.ol9", memory_in_mbs = 100 } }
  }

  expect_failures = [var.functions]
}

run "rejects_timeout_past_sync_limit" {
  command = plan

  variables {
    functions = { livetest = { files = { "function/func.py" = "" }, runtime = "python312.ol9", timeout_in_seconds = 301 } }
  }

  expect_failures = [var.functions]
}

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- make computed ids, the key and its fingerprint known during plan ---
  override_resource {
    target          = tls_private_key.this
    override_during = plan
    values = {
      private_key_pem = "-----BEGIN RSA PRIVATE KEY-----\nMOCK\n-----END RSA PRIVATE KEY-----\n"
      public_key_pem  = "-----BEGIN PUBLIC KEY-----\nMOCK\n-----END PUBLIC KEY-----\n"
    }
  }
  override_resource {
    target          = oci_identity_user.this
    override_during = plan
    values          = { id = "ocid1.user.oc1..vagabond" }
  }
  override_resource {
    target          = oci_identity_api_key.this
    override_during = plan
    values          = { fingerprint = "ab:cd:ef:00:11:22:33:44:55:66:77:88:99:aa:bb:cc" }
  }
  override_resource {
    target          = oci_identity_compartment.this
    override_during = plan
    values          = { id = "ocid1.compartment.oc1..vagabond" }
  }
  override_resource {
    target          = oci_functions_application.this
    override_during = plan
    values          = { id = "ocid1.fnapp.oc1.phx.vagabond" }
  }
  override_resource {
    target          = oci_functions_function.this["livetest"]
    override_during = plan
    values          = { id = "ocid1.fnfunc.oc1.phx.livetest" }
  }

  # --- keyed by the consumer, as every generator's vault_data is ---
  assert {
    condition     = keys(output.vault_data) == ["vagabond"]
    error_message = "vault_data must be keyed by the consumer's name"
  }

  # --- the private key, which is the only secret ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].private_key) == "-----BEGIN RSA PRIVATE KEY-----\nMOCK\n-----END RSA PRIVATE KEY-----\n"
    error_message = "vault_data must carry the private key"
  }

  # --- and what names the key in each request's signature ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].tenancy) == var.tenancy_ocid && nonsensitive(output.vault_data["vagabond"].user) == "ocid1.user.oc1..vagabond"
    error_message = "vault_data must carry the tenancy and the user"
  }

  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].fingerprint) == "ab:cd:ef:00:11:22:33:44:55:66:77:88:99:aa:bb:cc" && nonsensitive(output.vault_data["vagabond"].region) == var.region
    error_message = "vault_data must carry the key fingerprint and the region"
  }

  # --- where the functions live ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].compartment_id) == "ocid1.compartment.oc1..vagabond" && nonsensitive(output.vault_data["vagabond"].application_id) == "ocid1.fnapp.oc1.phx.vagabond"
    error_message = "vault_data must carry the compartment and application"
  }

  # --- each function's OCID as function_<name> ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].function_livetest) == "ocid1.fnfunc.oc1.phx.livetest"
    error_message = "vault_data must carry each function's OCID as function_<name>"
  }

  # --- non-sensitive views of the identifiers ---
  assert {
    condition     = output.function_ids["livetest"] == "ocid1.fnfunc.oc1.phx.livetest"
    error_message = "function_ids must expose each function's OCID"
  }

  assert {
    condition     = output.application_id == "ocid1.fnapp.oc1.phx.vagabond"
    error_message = "application_id must expose the application's OCID"
  }
}
