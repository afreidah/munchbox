# -------------------------------------------------------------------------------
# Prometheus Metrics Policy - Vault ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Prometheus read access to Vault's metrics endpoint for monitoring.
# -------------------------------------------------------------------------------
path "sys/metrics" {
  capabilities = ["read", "sudo", "list"]
}
