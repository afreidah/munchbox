# -------------------------------------------------------------------------------
# Munchbox Environment Configuration
#
# Project: Munchbox / Author: Alex Freidah
#
# Shell environment variables for CLI tools. Source this file to configure
# Vault, Nomad, and Consul CLI access from the local workstation.
#
# Addresses and cert paths are set unconditionally; the Vault secret lookups
# below them only run when Vault answers, so sourcing this off-network costs
# two seconds instead of one client timeout per secret.
#
# Usage: source ~/tools/munchbox/munchbox-env.sh
# -------------------------------------------------------------------------------

# Vault
export VAULT_ADDR="${VAULT_ADDR-https://192.168.68.61:8200}"
export VAULT_CACERT="${VAULT_CACERT-$HOME/.munchbox/vault/ca.crt}"
export VAULT_TOKEN=$(cat ~/.vault-token 2>/dev/null)

# Bound the per-secret wait for a Vault that accepts the connection but stalls.
export VAULT_CLIENT_TIMEOUT=5

# Nomad
export NOMAD_ADDR="${NOMAD_ADDR-https://192.168.68.61:4646}"
export NOMAD_CACERT="${NOMAD_CACERT-$HOME/.munchbox/nomad/ca.crt}"
export NOMAD_CLIENT_CERT="${NOMAD_CLIENT_CERT-$HOME/.munchbox/nomad/client.crt}"
export NOMAD_CLIENT_KEY="${NOMAD_CLIENT_KEY-$HOME/.munchbox/nomad/client.key}"

# Consul
export CONSUL_HTTP_ADDR="${CONSUL_HTTP_ADDR-https://192.168.68.61:8501}"
export CONSUL_CACERT="${CONSUL_CACERT-$HOME/.munchbox/consul/ca.crt}"
export CONSUL_CLIENT_CERT="${CONSUL_CLIENT_CERT-$HOME/.munchbox/consul/client.crt}"
export CONSUL_CLIENT_KEY="${CONSUL_CLIENT_KEY-$HOME/.munchbox/consul/client.key}"

# Terragrunt
export TG_STRICT_COMMANDS=false
export TG_TF_FORWARD_STDOUT=true
export TG_DOWNLOAD_DIR=/tmp/terragrunt-cache
export TERRAGRUNT_DOWNLOAD=/tmp/terragrunt-cache

# Enable Terragrunt's provider cache server
export TG_PROVIDER_CACHE=1
export TG_PROVIDER_CACHE_DIR="/tmp/terragrunt-provider-cache"

# Forgejo
export FORGEJO_HOST=http://forgejo.service.consul:30028

# Aptly (for package publishing). Admin password is TF-managed at
# secret/aptly-admin (terragrunt global/aptly-secrets -> global/vault-secrets);
# secret/aptly retains only the GPG + S3 keys.
export APTLY_USER=admin
export APTLY_REPOSITORY=munchbox
export APTLY_PREFIX=s3:munchbox:
# Publish over the internal Consul address, not the public apt.munchbox.cc:
# the public path routes through the Cloudflare tunnel + traefik, whose
# response timeouts kill the (synchronous) publish-switch. Direct to the
# aptly nginx on the LAN it returns in milliseconds. Apt clients still use
# apt.munchbox.cc; this only affects publishing tooling that reads APTLY_ENDPOINT.
export APTLY_ENDPOINT=http://aptly.service.consul:8089

# Vaultwarden (for Terraform/Terragrunt bitwarden provider)
# Set your personal Vaultwarden master password before running vaultwarden-secrets
export VAULTWARDEN_MASTER_PASSWORD="$(vault kv get -field=password secret/vaultwarden/master-password)"

# Proxmox (for Terraform/Terragrunt)
export PM_API_URL=https://192.168.68.65:8006/api2/json
export PM_API_TOKEN_ID="$(vault kv get -field=id secret/proxmox/api-token)"
export PM_API_TOKEN_SECRET="$(vault kv get -field=secret secret/proxmox/api-token)"

# Oracle Cloud (for Terraform/Terragrunt)
# OCI provider uses ~/.oci/config for auth
export OCI_COMPARTMENT_ID="$(vault kv get -field=compartment_id secret/oci/account)"
export OCI_USER_OCID="$(vault kv get -field=user_ocid secret/oci/account)"
export OCI_REGION="us-phoenix-1"

# IBM Cloud (for Terraform/Terragrunt)
export IBM_REGION=us-east

# WireGuard keys for cloud nodes (generate with: wg genkey)
# Public keys need to be added to homelab WireGuard server
export WG_PRIVATE_KEY_ORACLE_NODE_1="" # wg genkey
export WG_PRIVATE_KEY_ORACLE_NODE_2="" # wg genkey
export MUNCHBOX_WG_SERVER_PUBKEY=""    # Your homelab WireGuard server public key
export MUNCHBOX_WG_ENDPOINT=""         # e.g., home.example.com:51820

export DOCKER_REGISTRY=registry.munchbox.cc

# Temporal Configuration
export TEMPORAL_ADDRESS="temporal-server.service.consul:7233"
export TEMPORAL_NAMESPACE="default"

# s3-orchestrator admin CLI: point a local `s3-orchestrator admin <cmd>` at the
# running cluster instance without a server config (flag -> env -> config).
export S3O_ADMIN_ADDR=https://s3.munchbox.cc

# PostgreSQL: point psql at the Patroni primary via haproxy-postgres, with the
# admin/superuser creds from Vault. Lets `psql` run with no flags. TLS is
# required by the server (sslmode=require; no client cert).
export PGHOST="haproxy-postgres.service.consul"
export PGPORT="5433"
export PGDATABASE="postgres"
export PGSSLMODE="require"

# AWS CLI: point at s3-orchestrator (the "unified" S3 multiplexer). Uses the
# internal endpoint -- the public s3.munchbox.cc edge is oauth-gated and 401s
# on SigV4 CLI requests. Creds are the unified bucket's, from Vault. Lets
# `aws s3 ls s3://unified/...` run with no flags.
export AWS_ENDPOINT_URL="http://s3-orchestrator.service.consul:9000"
export AWS_DEFAULT_REGION="us-east-1"

# -------------------------------------------------------------------------------
# Vault reachability gate
#
# Everything past this point calls `vault kv get`, which blocks for a full
# client timeout per secret when Vault is unreachable (off the WARP tunnel,
# homelab down). One short TCP probe decides for all of them.
# -------------------------------------------------------------------------------
_mb_vault_target="${VAULT_ADDR#*://}"
_mb_vault_target="${_mb_vault_target%%/*}"
_mb_vault_host="${_mb_vault_target%:*}"
_mb_vault_port="${_mb_vault_target##*:}"
[[ "$_mb_vault_port" == "$_mb_vault_host" ]] && _mb_vault_port=8200

if ! timeout 2 bash -c "echo > /dev/tcp/${_mb_vault_host}/${_mb_vault_port}" 2>/dev/null; then
  [[ $- == *i* ]] && echo "munchbox-env: Vault unreachable at ${_mb_vault_host}:${_mb_vault_port}; skipping secret lookups." >&2
  unset _mb_vault_target _mb_vault_host _mb_vault_port
  return 0 2>/dev/null || exit 0
fi
unset _mb_vault_target _mb_vault_host _mb_vault_port

# Nomad
export NOMAD_TOKEN=$(vault kv get -field=token secret/nomad/management-token 2>/dev/null)

# Consul
# A caller that already has a token keeps it, the way CONSUL_HTTP_ADDR works
# above. The Vault read silences its own errors, so overwriting unconditionally
# replaces a working token with an empty string the moment the read fails.
export CONSUL_HTTP_TOKEN="${CONSUL_HTTP_TOKEN:-$(vault kv get -field=token secret/consul/bootstrap-token 2>/dev/null)}"
# Terraform variable for consul-acls
export TF_VAR_consul_bootstrap_token="$CONSUL_HTTP_TOKEN"

# OAuth2-Proxy (for Terraform/Terragrunt)
export OAUTH2_PROXY_CLIENT_ID=$(vault kv get -field=client_id secret/oauth2-proxy 2>/dev/null)
export OAUTH2_PROXY_CLIENT_SECRET=$(vault kv get -field=client_secret secret/oauth2-proxy 2>/dev/null)
export OAUTH2_PROXY_COOKIE_SECRET=$(vault kv get -field=cookie_secret secret/oauth2-proxy 2>/dev/null)

# Cloudflare (for Terraform/Terragrunt)
export CLOUDFLARE_API_TOKEN=$(vault kv get -field=cloudflare_api_token secret/dns 2>/dev/null)

# Pi-hole (for Terraform/Terragrunt)
# NOTE: Using TF_VAR_ prefix to avoid conflict with pihole provider's PIHOLE_PASSWORD env var
export TF_VAR_pihole_password_primary=$(vault kv get -field=password secret/pihole/green 2>/dev/null)
export TF_VAR_pihole_password_secondary=$(vault kv get -field=password secret/pihole/logan 2>/dev/null)

# Forgejo (for Terraform/Terragrunt)
export FORGEJO_API_TOKEN=$(vault kv get -field=api_token secret/forgejo 2>/dev/null)

# Grafana (for Terraform/Terragrunt dashboard provisioning)
export TF_VAR_grafana_admin_user=$(vault kv get -field=admin_user secret/grafana 2>/dev/null)
export TF_VAR_grafana_admin_password=$(vault kv get -field=admin_password secret/grafana 2>/dev/null)

# Jellyfin (for Terraform/Terragrunt config provisioning)
export TF_VAR_jellyfin_endpoint=$(vault kv get -field=endpoint secret/jellyfin 2>/dev/null)
export TF_VAR_jellyfin_api_key=$(vault kv get -field=api_key secret/jellyfin 2>/dev/null)

# Aptly
export APTLY_PASS=$(vault kv get -field=password secret/aptly-admin 2>/dev/null)

# IBM Cloud
export IC_API_KEY=$(vault kv get -field=api_key secret/ibm-cloud 2>/dev/null)
export IBMCLOUD_API_KEY="$IC_API_KEY"

# s3-orchestrator admin CLI: requests are SigV4-signed as of v0.143.0, so the
# root keypair replaces the admin token. Same Vault fields, which the config
# now feeds to auth.root.
export S3O_ACCESS_KEY_ID=$(vault kv get -field=ui_admin_key secret/s3-orchestrator 2>/dev/null)
export S3O_SECRET_ACCESS_KEY=$(vault kv get -field=ui_admin_secret secret/s3-orchestrator 2>/dev/null)

# PostgreSQL
export PGUSER=$(vault kv get -field=username secret/postgres-shared/root 2>/dev/null)
export PGPASSWORD=$(vault kv get -field=password secret/postgres-shared/root 2>/dev/null)

# AWS CLI
export AWS_ACCESS_KEY_ID=$(vault kv get -field=access_key secret/s3-bucket/unified 2>/dev/null)
export AWS_SECRET_ACCESS_KEY=$(vault kv get -field=secret_key secret/s3-bucket/unified 2>/dev/null)
