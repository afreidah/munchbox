# -----------------------------------------------------------------------------
# NOMAD-ACLS MODULE - INPUT VARIABLES
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable Categories:
#   - Core: Bootstrap token and Vault mount path
#   - Policies: Map of Nomad ACL policies with rules
#   - Tokens: Map of Nomad ACL tokens with policy bindings
#   - Vault Secrets: Map of secrets to store in Vault KV
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# CORE CONFIGURATION
# -------------------------------------------------------------------------

# nomad provider reads NOMAD_TOKEN from env; var kept for env_helper contract
# tflint-ignore: terraform_unused_declarations
variable "nomad_bootstrap_token" {
  description = "Nomad ACL bootstrap token (from 'nomad acl bootstrap' command)"
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
  description = "Map of Nomad ACL policies to create"
  type = map(object({
    description = optional(string, "")
    rules_hcl   = string
  }))
  default = {}
}

# -------------------------------------------------------------------------
# TOKENS
# -------------------------------------------------------------------------

variable "tokens" {
  description = "Map of Nomad ACL tokens to create"
  type = map(object({
    type       = optional(string, "client")
    policies   = list(string)
    expiration = optional(string, null)
  }))
  default = {}
}

# -------------------------------------------------------------------------
# VAULT SECRETS
# -------------------------------------------------------------------------

variable "vault_secrets" {
  description = "Map of secrets to store in Vault KV with token references"
  type = map(object({
    vault_path       = string
    token_key        = string
    token_field_name = optional(string, "token")
    extra_data       = optional(map(string), {})
  }))
  default = {}
}

# -------------------------------------------------------------------------
# EXTRA DATA FOR VAULT SECRETS (CROSS-MODULE)
# -------------------------------------------------------------------------

variable "extra_secret_values" {
  description = "Map of extra values to inject into vault secrets (e.g., consul tokens from other modules)"
  type        = map(string)
  default     = {}
  sensitive   = true
}
