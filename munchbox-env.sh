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
# A caller that already has a token keeps it; the file is a login token, and
# reading a missing one replaces the caller's with an empty string.
export VAULT_TOKEN="${VAULT_TOKEN:-$(cat ~/.vault-token 2>/dev/null)}"

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

# -------------------------------------------------------------------------------
# Secret lookups
#
# Every read below goes through _mb_secret, which records a failure instead of
# exporting an empty string. An empty credential is not inert: it travels into
# a provider and comes back as whatever that provider makes of it, three layers
# from the cause. An unreadable secret/ibm-cloud surfaces as "token is
# malformed: token contains an invalid number of segments"; an unreadable
# secret/edge-proxy/b2 surfaces as "no secret found", which reads as missing
# rather than forbidden. The read is the only place that still knows what
# actually went wrong, so it is where the complaint belongs.
# -------------------------------------------------------------------------------
_mb_missing=()

# _mb_secret VAR FIELD PATH - export VAR from a Vault field, or record why not.
# stderr is captured rather than discarded, so the recorded reason is Vault's.
_mb_secret() {
  local var=$1 field=$2 path=$3 out rc
  out=$(vault kv get -field="$field" "$path" 2>&1)
  rc=$?
  if ((rc != 0)); then
    _mb_missing+=("${path}#${field}: ${out%%$'\n'*}")
    return 0
  fi
  if [[ -z $out ]]; then
    _mb_missing+=("${path}#${field}: read succeeded but the field is empty")
    return 0
  fi
  export "${var}=${out}"
}

# Vaultwarden (for Terraform/Terragrunt bitwarden provider)
# Set your personal Vaultwarden master password before running vaultwarden-secrets
_mb_secret VAULTWARDEN_MASTER_PASSWORD password secret/vaultwarden/master-password

# Proxmox (for Terraform/Terragrunt)
export PM_API_URL=https://192.168.68.65:8006/api2/json
_mb_secret PM_API_TOKEN_ID id secret/proxmox/api-token
_mb_secret PM_API_TOKEN_SECRET secret secret/proxmox/api-token

# Oracle Cloud (for Terraform/Terragrunt)
# OCI provider uses ~/.oci/config for auth
_mb_secret OCI_COMPARTMENT_ID compartment_id secret/oci/account
_mb_secret OCI_USER_OCID user_ocid secret/oci/account
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
  unset -f _mb_secret
  unset _mb_missing
  return 0 2>/dev/null || exit 0
fi
unset _mb_vault_target _mb_vault_host _mb_vault_port

# Nomad
_mb_secret NOMAD_TOKEN token secret/nomad/management-token

# Consul
# A caller that already has a token keeps it, the way CONSUL_HTTP_ADDR works
# above: overwriting unconditionally would replace a working token the moment
# the read fails.
[[ -n ${CONSUL_HTTP_TOKEN:-} ]] || _mb_secret CONSUL_HTTP_TOKEN token secret/consul/bootstrap-token
# Terraform variable for consul-acls
export TF_VAR_consul_bootstrap_token="${CONSUL_HTTP_TOKEN:-}"

# OCI API signing key. The provider reads ~/.oci/config on a workstation; a CI
# runner has no such file, so the key is passed as provider config instead.
export OCI_PRIVATE_KEY=$(vault kv get -field=private_key secret/oci/account 2>/dev/null)

# GCP. The google provider's `credentials` argument takes a service account
# key, which an authorized_user token is not, so the ADC is written to disk and
# found by path -- the only form the SDK accepts for this credential type.
_mb_gcp_adc="${XDG_RUNTIME_DIR:-/tmp}/munchbox-gcp-adc.json"
if vault kv get -field=credentials secret/gcp/adc 2>/dev/null >"${_mb_gcp_adc}.tmp"; then
  chmod 600 "${_mb_gcp_adc}.tmp"
  mv "${_mb_gcp_adc}.tmp" "$_mb_gcp_adc"
  export GOOGLE_APPLICATION_CREDENTIALS="$_mb_gcp_adc"
else
  rm -f "${_mb_gcp_adc}.tmp"
fi
unset _mb_gcp_adc

# OAuth2-Proxy (for Terraform/Terragrunt)
_mb_secret OAUTH2_PROXY_CLIENT_ID client_id secret/oauth2-proxy
_mb_secret OAUTH2_PROXY_CLIENT_SECRET client_secret secret/oauth2-proxy
_mb_secret OAUTH2_PROXY_COOKIE_SECRET cookie_secret secret/oauth2-proxy

# Cloudflare (for Terraform/Terragrunt)
_mb_secret CLOUDFLARE_API_TOKEN cloudflare_api_token secret/dns

# Pi-hole (for Terraform/Terragrunt)
# NOTE: Using TF_VAR_ prefix to avoid conflict with pihole provider's PIHOLE_PASSWORD env var
_mb_secret TF_VAR_pihole_password_primary password secret/pihole/green
_mb_secret TF_VAR_pihole_password_secondary password secret/pihole/logan

# Forgejo (for Terraform/Terragrunt)
_mb_secret FORGEJO_API_TOKEN api_token secret/forgejo

# Grafana (for Terraform/Terragrunt dashboard provisioning)
_mb_secret TF_VAR_grafana_admin_user admin_user secret/grafana
_mb_secret TF_VAR_grafana_admin_password admin_password secret/grafana

# Jellyfin (for Terraform/Terragrunt config provisioning)
_mb_secret TF_VAR_jellyfin_endpoint endpoint secret/jellyfin
_mb_secret TF_VAR_jellyfin_api_key api_key secret/jellyfin

# Aptly
_mb_secret APTLY_PASS password secret/aptly-admin

# IBM Cloud
_mb_secret IC_API_KEY api_key secret/ibm-cloud
export IBMCLOUD_API_KEY="${IC_API_KEY:-}"

# s3-orchestrator admin CLI: requests are SigV4-signed as of v0.143.0, so the
# root keypair replaces the admin token. Same Vault fields, which the config
# now feeds to auth.root.
_mb_secret S3O_ACCESS_KEY_ID ui_admin_key secret/s3-orchestrator
_mb_secret S3O_SECRET_ACCESS_KEY ui_admin_secret secret/s3-orchestrator

# PostgreSQL
_mb_secret PGUSER username secret/postgres-shared/root
_mb_secret PGPASSWORD password secret/postgres-shared/root

# AWS CLI
_mb_secret AWS_ACCESS_KEY_ID access_key secret/s3-bucket/unified
_mb_secret AWS_SECRET_ACCESS_KEY secret_key secret/s3-bucket/unified

# -------------------------------------------------------------------------------
# Report
#
# One legible failure at the top of the run, naming the path and the field and
# Vault's own reason, instead of a different confusing provider error per unit
# further down.
# -------------------------------------------------------------------------------
if ((${#_mb_missing[@]} > 0)); then
  {
    echo "munchbox-env: ${#_mb_missing[@]} secret lookup(s) failed:"
    printf '  %s\n' "${_mb_missing[@]}"
    echo "munchbox-env: those credentials are unset. Fix the grant or the field before running terragrunt."
  } >&2
  unset -f _mb_secret
  unset _mb_missing
  return 1 2>/dev/null || exit 1
fi

unset -f _mb_secret
unset _mb_missing
