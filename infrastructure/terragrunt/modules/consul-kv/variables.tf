# -----------------------------------------------------------------------------
# CONSUL-KV MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "keys" {
  description = "Consul KV pairs to manage, keyed by path => value. Each is written with delete lifecycle, so removing an entry here removes it from Consul."
  type        = map(string)
  default     = {}
}

variable "datacenter" {
  description = "Consul datacenter to write the keys into."
  type        = string
  default     = "munchbox"
}
