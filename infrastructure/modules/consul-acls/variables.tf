# -----------------------------------------------------------------------------
# CONSUL-ACLS MODULE - INPUT VARIABLES
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable Categories:
#   - Core: Bootstrap token and Vault mount path
#   - Policies: Map of Consul ACL policies with rules
#   - Tokens: Map of Consul ACL tokens with policy bindings
#   - Vault Secrets: Map of secrets to store in Vault KV
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# CORE CONFIGURATION
# -------------------------------------------------------------------------

variable "consul_bootstrap_token" {
  description = "Consul ACL bootstrap token (from 'consul acl bootstrap' command)"
  type        = string
  sensitive   = true
}

variable "vault_mount" {
  description = "Vault KV v2 mount path for storing tokens"
  type        = string
  default     = "secret"
}

# -------------------------------------------------------------------------
# POLICIES
# -------------------------------------------------------------------------

variable "policies" {
  description = "Map of Consul ACL policies to create"
  type = map(object({
    rules       = string
    description = optional(string, "")
  }))
  default = {}
}

# -------------------------------------------------------------------------
# TOKENS
# -------------------------------------------------------------------------

variable "tokens" {
  description = "Map of Consul ACL tokens to create"
  type = map(object({
    description = optional(string, "")
    policies    = list(string)
    local       = optional(bool, false)
  }))
  default = {}
}

# -------------------------------------------------------------------------
# VAULT SECRETS
# -------------------------------------------------------------------------

variable "vault_secrets" {
  description = "Map of secrets to store in Vault KV with token references"
  type = map(object({
    vault_path          = string
    token_key           = string
    token_field_name    = optional(string, "token")
    include_accessor_id = optional(bool, true)
  }))
  default = {}
}

variable "store_bootstrap_token" {
  description = "Whether to store the bootstrap token in Vault"
  type        = bool
  default     = true
}

# -------------------------------------------------------------------------
# ANONYMOUS TOKEN
# -------------------------------------------------------------------------

variable "manage_anonymous_token" {
  description = "Whether to manage the anonymous token (set policies to empty for security)"
  type        = bool
  default     = true
}
