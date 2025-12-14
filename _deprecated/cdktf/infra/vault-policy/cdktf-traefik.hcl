# -------------------------------------------------------------------------------
# Traefik Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Traefik read access to its secrets and Vault metrics endpoint.
# -------------------------------------------------------------------------------

path "kv/data/traefik" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read", "sudo", "list"]
}
