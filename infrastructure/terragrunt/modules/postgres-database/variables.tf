# -----------------------------------------------------------------------------
# Postgres Database Module Variables
# -----------------------------------------------------------------------------

variable "app" {
  description = "Logical app name (= leaf dir basename); role name for newly-seeded apps"
  type        = string
}

variable "vault_kv_path" {
  description = "KV v2 path under secret/ holding this app's DB creds"
  type        = string
}

variable "username_field" {
  description = "Field in the Vault secret holding the role name"
  type        = string
  default     = "db_username"
}

variable "password_field" {
  description = "Field in the Vault secret holding the role password"
  type        = string
  default     = "db_password"
}

variable "databases" {
  description = "Databases owned by this app's role"
  type        = list(string)
}

variable "manage_secret" {
  description = "false = adopt existing creds from Vault (no rotation); true = generate a password and seed Vault (new apps)"
  type        = bool
  default     = false
}

variable "extensions" {
  description = "Per-database extensions to ensure exist, e.g. { temporal_visibility = [\"btree_gin\"] }"
  type        = map(list(string))
  default     = {}
}
