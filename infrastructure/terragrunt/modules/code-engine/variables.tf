# -----------------------------------------------------------------------------
# CODE-ENGINE Module Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# One map entry per Code Engine project. Everything a project needs is in the
# entry, so adding a consumer is a catalog line rather than a module change.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IBM PROVIDER AUTH
# -----------------------------------------------------------------------------

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to create the projects and identities"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region the provider operates in"
  type        = string
}

# -----------------------------------------------------------------------------
# PROJECTS
# -----------------------------------------------------------------------------

variable "projects" {
  description = <<-EOT
    Code Engine projects to create, keyed by project name. Each gets its own
    Service ID, an access policy scoped to that project, and an API key.

    roles defaults to Writer, which covers creating, reading and deleting job
    runs. Manager additionally allows reconfiguring the project itself and is
    not needed to dispatch work.
  EOT

  type = map(object({
    resource_group = optional(string, "Default")
    roles          = optional(list(string), ["Writer"])
    tags           = optional(map(string), {})
  }))

  default = {}
}
