# -------------------------------------------------------------------------------
# Consul ACL Configuration - Variables
# -------------------------------------------------------------------------------

variable "consul_bootstrap_token" {
  description = "Consul ACL bootstrap token (from bootstrap command)"
  type        = string
  sensitive   = true
}
