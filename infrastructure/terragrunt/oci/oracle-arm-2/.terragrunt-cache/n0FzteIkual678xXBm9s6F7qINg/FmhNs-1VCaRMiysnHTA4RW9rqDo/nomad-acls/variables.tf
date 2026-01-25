# -------------------------------------------------------------------------------
# Nomad ACLs Module - Input Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Configuration for Nomad ACL provisioning. Requires a management token with
# full ACL permissions. Provider configuration handled by Terragrunt.
# -------------------------------------------------------------------------------

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

variable "backup_consul_token" {
  description = "Consul token for backup-worker service"
  type        = string
  default     = ""
  sensitive   = true
}
