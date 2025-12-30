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

path "secret/data/prometheus-nomad" {
  capabilities = ["read"]
}

path "secret/data/nomad-ui" {
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

path "secret/data/redis-shared" {
  capabilities = ["read"]
}
path "secret/data/postgres-shared/root" {
  capabilities = ["read"]
}

path "secret/data/postgres-shared/replication" {
  capabilities = ["read"]
}

path "secret/data/nextcloud" {
  capabilities = ["read"]
}

path "secret/data/grafana" {
  capabilities = ["read"]
}

path "secret/data/deluge" {
  capabilities = ["read"]
}

path "secret/data/authentik" {
  capabilities = ["read"]
}

path "secret/data/cloudflared" {
  capabilities = ["read"]
}

path "secret/data/vaultwarden" {
  capabilities = ["read"]
}

path "secret/data/temporal" {
  capabilities = ["read"]
}

path "secret/data/authentik/*" {
  capabilities = ["read"]
}

path "sys/metrics" {
  capabilities = ["read"]
}

path "secret/data/trivy-dashboard" {
  capabilities = ["read"]
}

path "secret/data/forgejo" {
  capabilities = ["read"]
}

path "secret/data/forgejo-runner" {
  capabilities = ["read"]
}

path "secret/data/woodpecker" {
  capabilities = ["read"]
}

path "secret/data/umami" {
  capabilities = ["read"]
}

path "secret/data/s3-proxy" {
  capabilities = ["read"]
}

path "secret/data/patroni" {
  capabilities = ["read"]
}

path "secret/data/oauth2-proxy" {
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
# Backup Worker Policy (for Vault Raft snapshots)
# -------------------------------------------------------------------------

resource "vault_policy" "backup_worker" {
  name = "backup-worker"

  policy = <<EOT
# Allow taking Raft snapshots for disaster recovery
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
EOT
}
