# -----------------------------------------------------------------------------
# CONSUL ACL TOKENS
# -----------------------------------------------------------------------------
#
# Creates ACL tokens bound to policies for service authentication. Tokens
# are stored in Vault KV (see vault-secrets.tf) and never exposed in outputs.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "consul_acl_token" "nomad_server" {
  description = "Token for Nomad servers"
  policies    = [consul_acl_policy.nomad_server.name]
  local       = false
}

resource "consul_acl_token" "nomad_client" {
  description = "Token for Nomad clients"
  policies    = [consul_acl_policy.nomad_client.name]
  local       = false
}

resource "consul_acl_token" "vault_storage" {
  description = "Token for Vault storage backend"
  policies    = [consul_acl_policy.vault_storage.name]
  local       = false
}

resource "consul_acl_token" "consul_agent" {
  description = "Token for Consul client agents"
  policies    = [consul_acl_policy.consul_agent.name]
  local       = false
}

resource "consul_acl_token" "traefik" {
  description = "Token for Traefik reverse proxy"
  policies    = [consul_acl_policy.traefik.name]
  local       = false
}

resource "consul_acl_token" "prometheus" {
  description = "Token for Prometheus service discovery"
  policies    = [consul_acl_policy.prometheus.name]
  local       = false
}

resource "consul_acl_token" "patroni" {
  description = "Token for Patroni PostgreSQL HA cluster"
  policies    = [consul_acl_policy.patroni.name]
  local       = false
}

resource "consul_acl_token" "terraform_ci" {
  description = "Token for CI/CD terraform state management"
  policies    = [consul_acl_policy.terraform_ci.name]
  local       = false
}

# -----------------------------------------------------------------------------
# ANONYMOUS TOKEN
# -----------------------------------------------------------------------------

# Built-in token used when no token is provided. Managed with no policies
# to enforce default_policy=deny security model.
resource "consul_acl_token" "anonymous" {
  accessor_id = "00000000-0000-0000-0000-000000000002"
  description = "Anonymous Token - intentionally has no policies for security"
  policies    = []
  local       = false

  lifecycle {
    prevent_destroy = true
  }
}
