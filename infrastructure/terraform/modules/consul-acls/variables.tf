# -----------------------------------------------------------------------------
# CONSUL ACLS MODULE - INPUT VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

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
