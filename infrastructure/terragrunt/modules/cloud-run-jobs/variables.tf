# -----------------------------------------------------------------------------
# CLOUD-RUN-JOBS Module Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# One map entry per consumer. Adding one is a catalog line rather than a module
# change.
# -----------------------------------------------------------------------------

variable "project" {
  description = "GCP project the jobs and identities live in"
  type        = string
}

variable "region" {
  description = "Region job executions run in, carried to the consumer so it can build the API endpoint"
  type        = string
  default     = "us-central1"
}

variable "services" {
  description = <<-EOT
    APIs to enable on the project. Cloud Run to submit jobs, Logging to read
    what they printed, IAM Credentials so the dispatcher can act as the runtime
    identity.
  EOT

  type = list(string)

  default = [
    "run.googleapis.com",
    "logging.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

variable "consumers" {
  description = <<-EOT
    Consumers to provision, keyed by name. Each gets a dispatcher identity with
    a key, and a runtime identity the containers execute as.

    roles are granted to the dispatcher at project scope. The defaults are the
    minimum for the job: run.developer creates, executes and deletes jobs;
    logging.viewer reads their output. run.admin would additionally allow
    changing services, which nothing dispatching work needs.
  EOT

  type = map(object({
    roles = optional(list(string), [
      "roles/run.developer",
      "roles/logging.viewer",
    ])
  }))

  default = {}
}
