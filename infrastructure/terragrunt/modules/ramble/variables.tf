# -----------------------------------------------------------------------------
# RAMBLE Module Variables
# -----------------------------------------------------------------------------

variable "ramble_token" {
  description = "Ramble API token with write scope; sourced from TF_VAR_ramble_token via env_helper."
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Ramble user or organisation that owns every managed pack and job."
  type        = string
}

variable "resources" {
  description = "Packs and jobs published to Ramble, keyed by their Ramble name. A changed version adds that version; older versions stay."
  type = map(object({
    type           = string
    repository_url = string
    file_path      = optional(string, "")
    description    = string
    license        = string
    tags           = set(string)
    version        = string
  }))

  validation {
    condition     = alltrue([for r in values(var.resources) : contains(["pack", "job"], r.type)])
    error_message = "Each resource type must be pack or job."
  }
}
