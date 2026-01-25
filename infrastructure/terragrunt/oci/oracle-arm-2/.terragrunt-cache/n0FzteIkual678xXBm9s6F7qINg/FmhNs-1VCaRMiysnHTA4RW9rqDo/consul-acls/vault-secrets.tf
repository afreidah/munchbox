# -----------------------------------------------------------------------------
# VAULT KV SECRETS - TOKEN STORAGE
# -----------------------------------------------------------------------------
#
# Stores Consul ACL tokens in Vault KV v2 for secure retrieval by Ansible
# playbooks and applications. Tokens are never exposed in Terraform outputs.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "vault_kv_secret_v2" "consul_bootstrap" {
  mount = var.vault_mount
  name  = "consul/bootstrap-token"

  data_json = jsonencode({
    token       = var.consul_bootstrap_token
    description = "Consul ACL bootstrap token - CRITICAL"
  })
}

resource "vault_kv_secret_v2" "nomad_server_token" {
  mount = var.vault_mount
  name  = "consul/nomad-server-token"

  data_json = jsonencode({
    token       = consul_acl_token.nomad_server.id
    accessor_id = consul_acl_token.nomad_server.accessor_id
  })
}

resource "vault_kv_secret_v2" "nomad_client_token" {
  mount = var.vault_mount
  name  = "consul/nomad-client-token"

  data_json = jsonencode({
    token       = consul_acl_token.nomad_client.id
    accessor_id = consul_acl_token.nomad_client.accessor_id
  })
}

resource "vault_kv_secret_v2" "vault_storage_token" {
  mount = var.vault_mount
  name  = "consul/vault-storage-token"

  data_json = jsonencode({
    token       = consul_acl_token.vault_storage.id
    accessor_id = consul_acl_token.vault_storage.accessor_id
  })
}

resource "vault_kv_secret_v2" "consul_agent_token" {
  mount = var.vault_mount
  name  = "consul/agent-token"

  data_json = jsonencode({
    token       = consul_acl_token.consul_agent.id
    accessor_id = consul_acl_token.consul_agent.accessor_id
  })
}

resource "vault_kv_secret_v2" "traefik" {
  mount = var.vault_mount
  name  = "traefik"

  data_json = jsonencode({
    consul_token = consul_acl_token.traefik.id
  })
}

resource "vault_kv_secret_v2" "prometheus" {
  mount = var.vault_mount
  name  = "prometheus"

  data_json = jsonencode({
    consul_token = consul_acl_token.prometheus.id
  })
}

resource "vault_kv_secret_v2" "patroni" {
  mount = var.vault_mount
  name  = "patroni"

  data_json = jsonencode({
    consul_token = consul_acl_token.patroni.id
    accessor_id  = consul_acl_token.patroni.accessor_id
  })
}

resource "vault_kv_secret_v2" "terraform_ci_token" {
  mount = var.vault_mount
  name  = "consul/terraform-ci-token"

  data_json = jsonencode({
    token       = consul_acl_token.terraform_ci.id
    accessor_id = consul_acl_token.terraform_ci.accessor_id
  })
}
