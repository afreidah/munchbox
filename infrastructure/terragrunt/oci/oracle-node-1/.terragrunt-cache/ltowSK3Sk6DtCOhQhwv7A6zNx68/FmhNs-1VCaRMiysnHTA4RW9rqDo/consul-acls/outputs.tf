# -----------------------------------------------------------------------------
# CONSUL ACLS MODULE - OUTPUTS
# -----------------------------------------------------------------------------
#
# Exposes policy names and Vault paths for verification. Token secrets are
# stored in Vault KV and intentionally not exposed here.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "policies" {
  description = "Map of created ACL policy names"
  value = {
    nomad_server  = consul_acl_policy.nomad_server.name
    nomad_client  = consul_acl_policy.nomad_client.name
    vault_storage = consul_acl_policy.vault_storage.name
    consul_agent  = consul_acl_policy.consul_agent.name
    traefik       = consul_acl_policy.traefik.name
    prometheus    = consul_acl_policy.prometheus.name
    patroni       = consul_acl_policy.patroni.name
    health_checks = consul_acl_policy.health_checks.name
    terraform_ci  = consul_acl_policy.terraform_ci.name
  }
}

output "vault_paths" {
  description = "Vault KV paths where tokens are stored"
  value = {
    bootstrap      = "${var.vault_mount}/consul/bootstrap-token"
    nomad_server   = "${var.vault_mount}/consul/nomad-server-token"
    nomad_client   = "${var.vault_mount}/consul/nomad-client-token"
    vault_storage  = "${var.vault_mount}/consul/vault-storage-token"
    consul_agent   = "${var.vault_mount}/consul/agent-token"
    traefik        = "${var.vault_mount}/traefik"
    prometheus     = "${var.vault_mount}/prometheus"
    patroni        = "${var.vault_mount}/patroni"
    terraform_ci   = "${var.vault_mount}/consul/terraform-ci-token"
  }
}
