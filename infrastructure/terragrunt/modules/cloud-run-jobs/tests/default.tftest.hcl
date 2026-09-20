# -----------------------------------------------------------------------------
# cloud-run-jobs module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the separation that makes the key safe to hand out: a dispatcher that
# can submit and read logs, a runtime identity holding nothing, and act-as
# granted on that one account rather than at the project.
# -----------------------------------------------------------------------------

mock_provider "google" {}

variables {
  project = "munchbox-test"
  region  = "us-central1"

  consumers = {
    vagabond = {}
  }
}

# -------------------------------------------------------------------------
# Two identities per consumer, named for their role
# -------------------------------------------------------------------------

run "identities" {
  command = plan

  assert {
    condition     = google_service_account.dispatcher["vagabond"].account_id == "vagabond-dispatch"
    error_message = "dispatcher account must be named <consumer>-dispatch"
  }

  assert {
    condition     = google_service_account.runtime["vagabond"].account_id == "vagabond-run"
    error_message = "runtime account must be named <consumer>-run"
  }

  # --- one of each, not one shared ---
  assert {
    condition     = length(google_service_account.dispatcher) == 1 && length(google_service_account.runtime) == 1
    error_message = "one dispatcher and one runtime per consumer"
  }
}

# -------------------------------------------------------------------------
# Least privilege: the dispatcher submits and reads, nothing more, and the
# runtime holds nothing at all
# -------------------------------------------------------------------------

run "dispatcher_roles" {
  command = plan

  # --- the two defaults, and only those ---
  assert {
    condition     = length(google_project_iam_member.dispatcher) == 2
    error_message = "dispatcher must hold exactly the two default roles"
  }

  assert {
    condition = alltrue([
      for m in google_project_iam_member.dispatcher :
      contains(["roles/run.developer", "roles/logging.viewer"], m.role)
    ])
    error_message = "dispatcher roles must be run.developer and logging.viewer"
  }

  # --- every grant is keyed to a consumer, so a role can only ever land on
  #     that consumer's dispatcher; the runtime is never a key here ---
  assert {
    condition     = alltrue([for k, _ in google_project_iam_member.dispatcher : startswith(k, "vagabond/")])
    error_message = "project roles must be granted per consumer to the dispatcher only"
  }
}

# -------------------------------------------------------------------------
# Act-as is scoped to the one runtime account, not the project
# -------------------------------------------------------------------------

run "act_as_is_scoped" {
  command = plan

  # --- the runtime account's resource name is computed, so pin it to make the
  #     scoping assertion resolvable at plan time ---
  override_resource {
    target          = google_service_account.runtime["vagabond"]
    override_during = plan
    values          = { name = "projects/munchbox-test/serviceAccounts/vagabond-run@munchbox-test.iam.gserviceaccount.com" }
  }

  assert {
    condition     = google_service_account_iam_member.act_as["vagabond"].role == "roles/iam.serviceAccountUser"
    error_message = "act-as must be granted as serviceAccountUser"
  }

  # --- granted on one service account resource rather than at the project, so
  #     the dispatcher cannot impersonate anything else living here ---
  assert {
    condition     = google_service_account_iam_member.act_as["vagabond"].service_account_id == "projects/munchbox-test/serviceAccounts/vagabond-run@munchbox-test.iam.gserviceaccount.com"
    error_message = "act-as must be scoped to this consumer's runtime account"
  }

  # --- one grant, not one per consumer-pair ---
  assert {
    condition     = length(google_service_account_iam_member.act_as) == 1
    error_message = "act-as must be granted once per consumer"
  }
}

# -------------------------------------------------------------------------
# Roles are overridable for a consumer that needs more
# -------------------------------------------------------------------------

run "roles_override" {
  command = plan

  variables {
    consumers = {
      vagabond = { roles = ["roles/run.admin"] }
    }
  }

  assert {
    condition     = length(google_project_iam_member.dispatcher) == 1
    error_message = "stated roles must replace the defaults rather than add to them"
  }
}

# -------------------------------------------------------------------------
# APIs are enabled and survive a destroy
# -------------------------------------------------------------------------

run "services" {
  command = plan

  assert {
    condition     = length(google_project_service.this) == 3
    error_message = "run, logging and iamcredentials must all be enabled"
  }

  # --- another consumer in the same project would lose the API otherwise ---
  assert {
    condition = alltrue([
      for s in google_project_service.this : s.disable_on_destroy == false
    ])
    error_message = "APIs must not be disabled when this module is destroyed"
  }
}

# -------------------------------------------------------------------------
# OUTPUTS: every declared output is asserted at least once
# -------------------------------------------------------------------------

run "outputs" {
  command = plan

  override_resource {
    target          = google_service_account_key.dispatcher["vagabond"]
    override_during = plan
    # --- base64 of {"type":"service_account"} ---
    values = { private_key = "eyJ0eXBlIjoic2VydmljZV9hY2NvdW50In0=" }
  }

  # --- emails are computed, so make them known for the output assertions ---
  override_resource {
    target          = google_service_account.dispatcher["vagabond"]
    override_during = plan
    values          = { email = "vagabond-dispatch@munchbox-test.iam.gserviceaccount.com" }
  }
  override_resource {
    target          = google_service_account.runtime["vagabond"]
    override_during = plan
    values = {
      email = "vagabond-run@munchbox-test.iam.gserviceaccount.com"
      # name is validated by the provider where act_as consumes it, so a
      # mocked random string fails the plan rather than the assertion.
      name = "projects/munchbox-test/serviceAccounts/vagabond-run@munchbox-test.iam.gserviceaccount.com"
    }
  }

  # --- decoded on the way out, so Vault holds usable JSON ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].credentials_json) == "{\"type\":\"service_account\"}"
    error_message = "vault_data must carry the decoded key JSON"
  }

  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].project) == var.project
    error_message = "vault_data must carry the project"
  }

  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].region) == var.region
    error_message = "vault_data must carry the region"
  }

  # --- the consumer needs the runtime email to submit a job that runs as it ---
  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].runtime_account_email) == google_service_account.runtime["vagabond"].email
    error_message = "vault_data must carry the runtime account email"
  }

  assert {
    condition     = nonsensitive(output.vault_data["vagabond"].dispatcher_email) == google_service_account.dispatcher["vagabond"].email
    error_message = "vault_data must carry the dispatcher email"
  }

  # --- non-sensitive views ---
  assert {
    condition     = output.dispatcher_emails["vagabond"] == google_service_account.dispatcher["vagabond"].email
    error_message = "dispatcher_emails must expose the dispatcher email"
  }

  assert {
    condition     = output.runtime_emails["vagabond"] == google_service_account.runtime["vagabond"].email
    error_message = "runtime_emails must expose the runtime email"
  }

  assert {
    condition     = contains(output.enabled_services, "run.googleapis.com")
    error_message = "enabled_services must list the Cloud Run API"
  }
}
