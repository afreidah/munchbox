# -------------------------------------------------------------------------------
# Traefik Nomad Read Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Traefik read access to secrets and Vault metrics for Nomad integration.
# -------------------------------------------------------------------------------

path "kv/data/traefik" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read", "sudo", "list"]
}
