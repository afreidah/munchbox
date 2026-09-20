# -----------------------------------------------------------------------------
# code-engine module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the composition that makes a credential safe to hand out: one project,
# Service ID, policy and key per catalog entry; the policy scoped to codeengine
# with Writer rather than Manager; and vault_data carrying the key alongside the
# coordinates it is useless without.
# -----------------------------------------------------------------------------

# A real resource group id is 32 lowercase hex characters, and the provider
# validates the shape, so the mock has to look like one.
mock_provider "ibm" {
  mock_data "ibm_resource_group" {
    defaults = { id = "0123456789abcdef0123456789abcdef" }
  }
}

variables {
  ibmcloud_api_key = "mock-api-key"
  region           = "us-south"

  projects = {
    vagabond = {
      resource_group = "Default"
      tags           = { project = "munchbox", purpose = "test" }
    }
  }
}

# -------------------------------------------------------------------------
# One of everything per catalog entry
# -------------------------------------------------------------------------

run "one_set_per_project" {
  command = plan

  # --- project named for its catalog key ---
  assert {
    condition     = ibm_code_engine_project.this["vagabond"].name == "vagabond"
    error_message = "project name must be the catalog key"
  }

  # --- exactly one of each resource for one entry ---
  assert {
    condition     = length(ibm_code_engine_project.this) == 1
    error_message = "one project per catalog entry"
  }

  assert {
    condition     = length(ibm_iam_service_id.this) == 1
    error_message = "one Service ID per catalog entry"
  }

  assert {
    condition     = length(ibm_iam_service_api_key.this) == 1
    error_message = "one API key per catalog entry"
  }
}

# -------------------------------------------------------------------------
# Naming: identities carry the project they belong to
# -------------------------------------------------------------------------

run "identity_naming" {
  command = plan

  # --- Service ID names the project so an account listing is readable ---
  assert {
    condition     = ibm_iam_service_id.this["vagabond"].name == "vagabond-code-engine"
    error_message = "Service ID must be named <project>-code-engine"
  }

  # --- key shares the convention ---
  assert {
    condition     = ibm_iam_service_api_key.this["vagabond"].name == "vagabond-code-engine"
    error_message = "API key must be named <project>-code-engine"
  }
}

# -------------------------------------------------------------------------
# Least privilege: Writer on codeengine, not Manager, not account-wide
# -------------------------------------------------------------------------

run "policy_is_least_privilege" {
  command = plan

  # --- Writer covers submitting and deleting job runs; Manager would also
  #     allow reconfiguring the project ---
  assert {
    condition     = ibm_iam_service_policy.this["vagabond"].roles == tolist(["Writer"])
    error_message = "policy must grant Writer only"
  }

  # --- scoped to codeengine rather than the whole account ---
  assert {
    condition     = ibm_iam_service_policy.this["vagabond"].resources[0].service == "codeengine"
    error_message = "policy must be scoped to the codeengine service"
  }

  # --- and to the resource group the project lives in ---
  assert {
    condition     = ibm_iam_service_policy.this["vagabond"].resources[0].resource_group_id == "0123456789abcdef0123456789abcdef"
    error_message = "policy must be scoped to the project's resource group"
  }
}

# -------------------------------------------------------------------------
# Roles are overridable for a consumer that genuinely needs more
# -------------------------------------------------------------------------

run "roles_override" {
  command = plan

  variables {
    projects = {
      vagabond = { resource_group = "Default", roles = ["Manager"] }
    }
  }

  assert {
    condition     = ibm_iam_service_policy.this["vagabond"].roles == tolist(["Manager"])
    error_message = "roles must come from the catalog entry when stated"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  # --- make computed ids and the key known during plan so outputs resolve ---
  override_resource {
    target          = ibm_code_engine_project.this["vagabond"]
    override_during = plan
    values = {
      project_id = "00000000-0000-0000-0000-000000000000"
      crn        = "crn:v1:bluemix:public:codeengine:us-south:a/acct::project:00000000-0000-0000-0000-000000000000::"
    }
  }
  override_resource {
    target          = ibm_iam_service_api_key.this["vagabond"]
    override_during = plan
    values          = { apikey = "mock-service-api-key" }
  }

  # --- the key itself, which is the only long-lived secret ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].api_key) == "mock-service-api-key"
    error_message = "vault_data must carry the service API key"
  }

  # --- and the coordinates the key is useless without ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].project_id) == "00000000-0000-0000-0000-000000000000"
    error_message = "vault_data must carry the project GUID"
  }

  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].region) == var.region
    error_message = "vault_data must carry the region"
  }

  # --- endpoint is derived from the region rather than stated twice ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].endpoint) == "https://api.${var.region}.codeengine.cloud.ibm.com/v2"
    error_message = "vault_data endpoint must be the region-derived API URL"
  }

  # --- non-sensitive views for anything that only needs identifiers ---
  assert {
    condition     = output.project_ids["vagabond"] == "00000000-0000-0000-0000-000000000000"
    error_message = "project_ids must expose the project GUID"
  }

  assert {
    condition     = output.service_id_names["vagabond"] == "vagabond-code-engine"
    error_message = "service_id_names must expose the Service ID name"
  }
}
