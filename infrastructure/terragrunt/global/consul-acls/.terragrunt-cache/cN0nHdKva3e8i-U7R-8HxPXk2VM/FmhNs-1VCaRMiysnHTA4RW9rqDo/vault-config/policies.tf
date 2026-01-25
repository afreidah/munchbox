# -------------------------------------------------------------------------------
# Vault Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# Access policies for infrastructure components and Nomad workloads. Controls
# which secrets each component can read/write.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# CONSUL TOKEN READ POLICY
# -------------------------------------------------------------------------

resource "vault_policy" "consul_token_read" {
  count = var.policies_enabled ? 1 : 0
  name  = "consul-token-read"

  policy = <<EOT
path "secret/data/consul/*" {
  capabilities = ["read"]
}
EOT
}

# -------------------------------------------------------------------------
# NOMAD SERVER POLICY
# -------------------------------------------------------------------------

resource "vault_policy" "nomad_server" {
  count = var.policies_enabled ? 1 : 0
  name  = "nomad-server"

  policy = <<EOT
path "secret/data/consul/nomad-server-token" {
  capabilities = ["read"]
}

path "pki_int/issue/nomad-server" {
  capabilities = ["create", "update"]
}
EOT
}

# -------------------------------------------------------------------------
# NOMAD CLIENT POLICY
# -------------------------------------------------------------------------

resource "vault_policy" "nomad_client" {
  count = var.policies_enabled ? 1 : 0
  name  = "nomad-client"

  policy = <<EOT
path "secret/data/consul/nomad-client-token" {
  capabilities = ["read"]
}

path "pki_int/issue/nomad-client" {
  capabilities = ["create", "update"]
}
EOT
}

# -------------------------------------------------------------------------
# NOMAD WORKLOADS POLICY
# -------------------------------------------------------------------------
# Grants access to secrets for Nomad jobs using workload identity.

resource "vault_policy" "nomad_workloads" {
  count = var.policies_enabled ? 1 : 0
  name  = "nomad-workloads"

  policy = <<EOT
# --- KV Secrets ---
%{for secret in var.workload_secrets~}
path "secret/data/${secret}" {
  capabilities = ["read"]
}
%{endfor~}

path "sys/metrics" {
  capabilities = ["read"]
}

# --- PKI Certificate Issuance ---
path "pki_int/issue/traefik" {
  capabilities = ["create", "update", "read"]
}

path "pki_int/issue/postgres" {
  capabilities = ["create", "update", "read"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}

# --- Consul Dynamic Tokens ---
path "consul/creds/*" {
  capabilities = ["read"]
}
EOT
}

# -------------------------------------------------------------------------
# VAULT CERT MANAGER POLICY
# -------------------------------------------------------------------------
# Allows vault-cert-manager to issue certificates for infrastructure services.

resource "vault_policy" "vault_cert_manager" {
  count = var.policies_enabled ? 1 : 0
  name  = "vault-cert-manager"

  policy = <<EOT
# Issue certificates for Consul servers and clients
path "pki_int/issue/consul-server" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/consul-client" {
  capabilities = ["create", "update"]
}

# Issue certificates for Nomad servers and clients
path "pki_int/issue/nomad-server" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/nomad-client" {
  capabilities = ["create", "update"]
}

# Read CA certificate
path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOT
}

# -------------------------------------------------------------------------
# BACKUP WORKER POLICY
# -------------------------------------------------------------------------
# Allows backup-worker to take Vault Raft snapshots for disaster recovery.

resource "vault_policy" "backup_worker" {
  count = var.policies_enabled ? 1 : 0
  name  = "backup-worker"

  policy = <<EOT
# Allow taking Raft snapshots for disaster recovery
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
EOT
}
