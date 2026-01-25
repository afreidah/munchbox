# -----------------------------------------------------------------------------
# CONSUL ACL POLICIES
# -----------------------------------------------------------------------------
#
# Defines ACL policies for Munchbox cluster services. Each policy grants
# specific permissions using Consul's ACL rule syntax. Policy rules are
# stored in the policies/ subdirectory as separate HCL files.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "consul_acl_policy" "nomad_server" {
  name  = "nomad-server"
  rules = file("${path.module}/policies/nomad-server.hcl")
}

resource "consul_acl_policy" "nomad_client" {
  name  = "nomad-client"
  rules = file("${path.module}/policies/nomad-client.hcl")
}

resource "consul_acl_policy" "vault_storage" {
  name  = "vault-storage"
  rules = file("${path.module}/policies/vault-storage.hcl")
}

resource "consul_acl_policy" "consul_agent" {
  name  = "consul-agent"
  rules = file("${path.module}/policies/consul-agent.hcl")
}

resource "consul_acl_policy" "traefik" {
  name  = "traefik"
  rules = file("${path.module}/policies/traefik.hcl")
}

resource "consul_acl_policy" "prometheus" {
  name  = "prometheus"
  rules = file("${path.module}/policies/prometheus.hcl")
}

resource "consul_acl_policy" "patroni" {
  name  = "patroni"
  rules = file("${path.module}/policies/patroni.hcl")
}

resource "consul_acl_policy" "health_checks" {
  name  = "health-checks"
  rules = file("${path.module}/policies/health-checks.hcl")
}

resource "consul_acl_policy" "terraform_ci" {
  name  = "terraform-ci"
  rules = file("${path.module}/policies/terraform-ci.hcl")
}
