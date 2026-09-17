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

# The grant vocabulary is two disjoint sets. Data-plane verbs answer what a
# request may do to objects in a bucket; the admin- ones answer what it may do
# to the deployment, and the orchestrator stores them in one field precisely
# because no combination of one can add up to the other. The validations below
# keep them apart, since a bucket grant carrying admin-read is a typo rather
# than a narrower kind of administrator.
variable "identities" {
  description = "Map of identity name to the grants it holds; each gets a user, a minted keypair written to Vault, and one grant resource per entry in its list"

  type = map(object({
    label = optional(string)
    grants = list(object({
      kind        = optional(string)
      name        = optional(string)
      permissions = list(string)
    }))
  }))

  default = {}

  # --- the name becomes a user name and a Vault path segment ---
  validation {
    condition     = alltrue([for name, _ in var.identities : can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", name))])
    error_message = "Identity names must be alphanumeric with _ . - and cannot start with a separator; the name is both a user name and a Vault path segment."
  }

  validation {
    condition     = alltrue([for i in var.identities : length(i.grants) > 0])
    error_message = "An identity holding no grants authenticates and reaches nothing."
  }

  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants : g.kind == null || contains(["bucket", "backend", "orchestrator"], g.kind)
      ]
    ]))
    error_message = "Grant kind is bucket, backend or orchestrator. Omitting it means bucket."
  }

  validation {
    condition = alltrue(flatten([
      for i in var.identities : [for g in i.grants : length(g.permissions) > 0]
    ]))
    error_message = "A grant conferring no permissions is not a grant."
  }

  # --- a bucket grant takes the data-plane vocabulary ---
  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants : [
          for p in g.permissions :
          contains(["list-buckets", "list", "read", "write", "delete", "tags", "all"], p)
        ] if g.kind == null || g.kind == "bucket"
      ]
    ]))
    error_message = "Bucket permissions are list-buckets, list, read, write, delete and tags, or all. The admin- vocabulary is not valid on a bucket."
  }

  # --- backend and orchestrator grants take the administrative one ---
  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants : [
          for p in g.permissions :
          contains([
            "admin-read", "admin-logs", "admin-maintain", "admin-convert", "admin-keys",
            "admin-cache", "admin-drain", "admin-decommission", "admin-config",
            "admin-provision", "admin-all",
          ], p)
        ] if g.kind == "backend" || g.kind == "orchestrator"
      ]
    ]))
    error_message = "Backend and orchestrator grants take the admin- vocabulary, or admin-all. Data-plane verbs are not valid on them."
  }

  # --- the orchestrator holds a set, so a repeat is a typo rather than a duplicate ---
  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants : length(g.permissions) == length(distinct(g.permissions))
      ]
    ]))
    error_message = "A permission is listed twice; the grant holds a set."
  }

  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants :
        !(contains(g.permissions, "all") || contains(g.permissions, "admin-all")) || length(g.permissions) == 1
      ]
    ]))
    error_message = "The all and admin-all shorthands already cover every other permission in their vocabulary; list one alone."
  }

  # --- there is one orchestrator, so its grant names nothing; the other kinds
  #     name the resource they are over, or * for every one of them ---
  validation {
    condition = alltrue(flatten([
      for i in var.identities : [
        for g in i.grants :
        g.kind == "orchestrator" ? g.name == null : (g.name != null && g.name != "")
      ]
    ]))
    error_message = "A bucket or backend grant names its target, or *. An orchestrator grant names nothing, because there is one."
  }

  # --- two grants of the same kind over the same name would be one resource ---
  validation {
    condition = alltrue([
      for i in var.identities :
      length(i.grants) == length(distinct([
        for g in i.grants : "${g.kind == null ? "bucket" : g.kind}/${g.name == null ? "" : g.name}"
      ]))
    ])
    error_message = "An identity declares a given kind and name once; a second grant over the same target replaces rather than adds to the first."
  }
}
