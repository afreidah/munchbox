# -----------------------------------------------------------------------------
# CLOUD-RUN-JOBS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants a consumer the ability to run Cloud Run jobs and read their output.
# Generic and map-driven: one catalog entry per consumer, each with its own
# identities and its own key.
#
# Two service accounts per consumer, not one. The dispatcher holds the key and
# submits work; the runtime is what the container actually runs as. Splitting
# them means the dispatcher's key cannot be used to act as the workload, and the
# workload has no permissions of its own.
#
# Vault-free, matching access-keys and code-engine: the key is a sensitive
# output and the vault-secrets leaf writes it.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# APIS
#
# Enabled here rather than assumed, so a fresh project converges. Never disabled
# on destroy: another consumer in the same project would lose the API with it.
# -----------------------------------------------------------------------------

resource "google_project_service" "this" {
  for_each = toset(var.services)

  project = var.project
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

# -----------------------------------------------------------------------------
# RUNTIME IDENTITY
#
# What the job's container runs as. Deliberately granted nothing: a CI task
# builds and tests, and anything it could reach with a project role is something
# a compromised dependency could reach too.
# -----------------------------------------------------------------------------

resource "google_service_account" "runtime" {
  for_each = var.consumers

  project      = var.project
  account_id   = "${each.key}-run"
  display_name = "${each.key} Cloud Run job runtime"
  description  = "Identity ${each.key} job containers execute as. Holds no project roles."
}

# -----------------------------------------------------------------------------
# DISPATCHER IDENTITY
#
# What Vagabond authenticates as. Creates job runs and reads their logs.
# -----------------------------------------------------------------------------

resource "google_service_account" "dispatcher" {
  for_each = var.consumers

  project      = var.project
  account_id   = "${each.key}-dispatch"
  display_name = "${each.key} Cloud Run job dispatcher"
  description  = "Submits Cloud Run jobs for ${each.key} and reads their output"
}

# -----------------------------------------------------------------------------
# DISPATCHER ROLES
#
# run.developer creates, executes and deletes jobs. logging.viewer reads what
# they printed, which is the whole reason this platform was chosen: the output
# comes back through a documented API rather than a paid log product.
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "dispatcher" {
  for_each = local.dispatcher_roles

  project = var.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.dispatcher[each.value.consumer].email}"
}

# -----------------------------------------------------------------------------
# ACTING AS THE RUNTIME
#
# Deploying a job that runs as a service account requires permission to act as
# it. Granted on the single runtime account rather than at the project, so the
# dispatcher cannot impersonate anything else that happens to live here.
# -----------------------------------------------------------------------------

resource "google_service_account_iam_member" "act_as" {
  for_each = var.consumers

  service_account_id = google_service_account.runtime[each.key].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.dispatcher[each.key].email}"
}

# -----------------------------------------------------------------------------
# DISPATCHER KEY
#
# The only long-lived secret. Google returns it base64-encoded; it is decoded
# here so what lands in Vault is the JSON a client library expects.
# -----------------------------------------------------------------------------

resource "google_service_account_key" "dispatcher" {
  for_each = var.consumers

  service_account_id = google_service_account.dispatcher[each.key].name
}

locals {
  # --- flattened so one resource covers every consumer's every role ---
  dispatcher_roles = {
    for pair in flatten([
      for name, consumer in var.consumers : [
        for role in consumer.roles : { consumer = name, role = role }
      ]
    ]) : "${pair.consumer}/${pair.role}" => pair
  }
}
