# -----------------------------------------------------------------------------
# S3-Orchestrator Module Variables
# -----------------------------------------------------------------------------

variable "address" {
  description = "Base URL of the orchestrator's admin API, for example https://s3.munchbox.cc"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.address))
    error_message = "Address must carry a scheme: http:// or https://."
  }

  validation {
    condition     = !endswith(var.address, "/")
    error_message = "Address must not end in a slash; the provider joins paths onto it."
  }
}

variable "root_credential_path" {
  description = "Vault KV path holding the keypair the deployment administers itself with; the fields are named by root_key_field and root_secret_field"
  type        = string
  default     = "s3-orchestrator"

  validation {
    condition     = length(var.root_credential_path) > 0 && !startswith(var.root_credential_path, "/") && !endswith(var.root_credential_path, "/")
    error_message = "Root credential path must be non-empty and carry no leading or trailing slash; the mount is given separately."
  }

  validation {
    condition     = !startswith(var.root_credential_path, "data/")
    error_message = "Give the KV v2 path without the data/ segment; the provider inserts it."
  }
}

variable "root_key_field" {
  description = "Field in root_credential_path holding the access key. Named ui_admin_key for historical reasons: before v0.143.0 it was the dashboard login rather than the deployment's root credential"
  type        = string
  default     = "ui_admin_key"

  validation {
    condition     = length(var.root_key_field) > 0
    error_message = "Root key field must name a field in the Vault secret."
  }
}

variable "root_secret_field" {
  description = "Field in root_credential_path holding the secret half of the root keypair"
  type        = string
  default     = "ui_admin_secret"

  validation {
    condition     = length(var.root_secret_field) > 0
    error_message = "Root secret field must name a field in the Vault secret."
  }

  validation {
    condition     = var.root_secret_field != var.root_key_field
    error_message = "The two halves of the root keypair cannot come from one field."
  }
}

variable "vault_mount" {
  description = "KV v2 mount the minted keypairs are written to"
  type        = string
  default     = "secret"

  validation {
    condition     = length(var.vault_mount) > 0 && !strcontains(var.vault_mount, "/")
    error_message = "Vault mount is a single path segment; put anything deeper in vault_prefix."
  }
}

variable "vault_prefix" {
  description = "Path prefix under vault_mount for the minted keypairs; each identity lands at <prefix>/<name>"
  type        = string
  default     = "s3-identity"

  validation {
    condition     = length(var.vault_prefix) > 0 && !startswith(var.vault_prefix, "/") && !endswith(var.vault_prefix, "/")
    error_message = "Vault prefix must be non-empty and carry no leading or trailing slash."
  }
}

variable "identities" {
  description = "Map of identity name to the bucket it reaches and what it may do there; each gets a user, a minted keypair written to Vault, and one grant"

  type = map(object({
    bucket      = string
    permissions = list(string)
    label       = optional(string)
  }))

  default = {}

  # --- the name becomes a user name and a Vault path segment ---
  validation {
    condition     = alltrue([for name, _ in var.identities : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", name))])
    error_message = "Identity names must be alphanumeric with _ . - and cannot start with a separator; the name is both a user name and a Vault path segment."
  }

  validation {
    condition     = alltrue([for i in var.identities : length(i.bucket) > 0])
    error_message = "Every identity names the bucket it reaches."
  }

  validation {
    condition     = alltrue([for i in var.identities : length(i.permissions) > 0])
    error_message = "An identity granted no permissions authenticates and reaches nothing."
  }

  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for p in i.permissions :
        contains(["list-buckets", "list", "read", "write", "delete", "tags", "all"], p)
      ]
    ]))
    error_message = "Bucket permissions are list-buckets, list, read, write, delete and tags, or all. The admin- vocabulary is not valid on a bucket."
  }

  # --- the orchestrator holds a set, so a repeat is a typo rather than a duplicate ---
  validation {
    condition     = alltrue([for i in var.identities : length(i.permissions) == length(distinct(i.permissions))])
    error_message = "A permission is listed twice; the grant holds a set."
  }

  validation {
    condition     = alltrue([for i in var.identities : !contains(i.permissions, "all") || length(i.permissions) == 1])
    error_message = "The all permission already covers every other one; list it alone."
  }
}
