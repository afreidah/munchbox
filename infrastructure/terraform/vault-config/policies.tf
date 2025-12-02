# -------------------------------------------------------------------------------
# Vault Policies
#
# Project: Munchbox / Author: Alex Freidah
#
# Access policies for infrastructure components and Nomad workloads.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Consul Token Access
# -------------------------------------------------------------------------

resource "vault_policy" "consul_token_read" {
  name = "consul-token-read"

  policy = <<EOT
path "secret/data/consul/*" {
  capabilities = ["read"]
}
EOT
}

# -------------------------------------------------------------------------
# Nomad Server Policy
# -------------------------------------------------------------------------

resource "vault_policy" "nomad_server" {
  name = "nomad-server"

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
# Nomad Client Policy
# -------------------------------------------------------------------------

resource "vault_policy" "nomad_client" {
  name = "nomad-client"

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
# Nomad Workloads Policy (for jobs using workload identity)
# -------------------------------------------------------------------------

resource "vault_policy" "nomad_workloads" {
  name = "nomad-workloads"

  policy = <<EOT
# --- KV Secrets ---
path "kv/data/traefik" {
  capabilities = ["read"]
}

path "kv/data/grafana" {
  capabilities = ["read"]
}

path "kv/data/backup-worker" {
  capabilities = ["read"]
}

path "kv/data/prometheus" {
  capabilities = ["read"]
}

path "secret/data/traefik" {
  capabilities = ["read"]
}

path "secret/data/prometheus" {
  capabilities = ["read"]
}

path "secret/data/hashiuisecret" {
  capabilities = ["read"]
}

path "secret/data/backup-worker" {
  capabilities = ["read"]
}

path "secret/data/alertmanager" {
  capabilities = ["read"]
}
path "secret/data/postgres-shared/root" {
  capabilities = ["read"]
}

path "secret/data/grafana" {
  capabilities = ["read"]
}

path "secret/data/deluge" {
  capabilities = ["read"]
}

path "secret/data/cloudflared" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read"]
}

# KV secrets for workloads
path "kv/data/traefik" {
  capabilities = ["read"]
}

# --- PKI Certificate Issuance ---
path "pki_int/issue/traefik" {
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
