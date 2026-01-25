# -------------------------------------------------------------------------------
# VAULT-CONFIG MODULE - INPUT VARIABLES
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable Categories:
#   - Feature Flags: Enable/disable module components
#   - KV Configuration: KV v2 secrets engine settings
#   - Consul Configuration: Consul secrets engine settings
#   - JWT Auth Configuration: Nomad workload identity settings
#   - Database Configuration: PostgreSQL secrets engine settings
#   - PKI Configuration: Certificate role settings
#   - Policy Configuration: Workload access control settings
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# FEATURE FLAGS
# -------------------------------------------------------------------------

variable "kv_enabled" {
  description = "Enable KV v2 secrets engine"
  type        = bool
  default     = true
}

variable "consul_secrets_enabled" {
  description = "Enable Consul secrets engine for dynamic token generation"
  type        = bool
  default     = true
}

variable "jwt_auth_enabled" {
  description = "Enable JWT auth backend for Nomad workload identity"
  type        = bool
  default     = true
}

variable "database_secrets_enabled" {
  description = "Enable database secrets engine for dynamic PostgreSQL credentials"
  type        = bool
  default     = false
}

variable "pki_roles_enabled" {
  description = "Enable PKI roles for certificate issuance"
  type        = bool
  default     = true
}

variable "policies_enabled" {
  description = "Enable Vault policies"
  type        = bool
  default     = true
}

# -------------------------------------------------------------------------
# KV CONFIGURATION
# -------------------------------------------------------------------------

variable "kv_path" {
  description = "Mount path for KV v2 secrets engine"
  type        = string
  default     = "secret"
}

# -------------------------------------------------------------------------
# CONSUL CONFIGURATION
# -------------------------------------------------------------------------

variable "consul_address" {
  description = "Consul server address for secrets engine"
  type        = string
  default     = "http://192.168.68.61:8500"
}

variable "consul_scheme" {
  description = "HTTP scheme for Consul connection"
  type        = string
  default     = "http"
}

variable "consul_bootstrap_token" {
  description = "Consul ACL bootstrap token for secrets engine"
  type        = string
  sensitive   = true
  default     = ""
}

# -------------------------------------------------------------------------
# JWT AUTH CONFIGURATION
# -------------------------------------------------------------------------

variable "nomad_jwks_url" {
  description = "Nomad JWKS URL for JWT auth backend"
  type        = string
  default     = "https://192.168.68.61:4646/.well-known/jwks.json"
}

# -------------------------------------------------------------------------
# DATABASE CONFIGURATION
# -------------------------------------------------------------------------

variable "postgres_host" {
  description = "PostgreSQL hostname for database secrets engine"
  type        = string
  default     = "postgres-shared.service.consul"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "database_roles" {
  description = "List of database roles to create"
  type        = list(string)
  default     = ["temporal", "kanboard"]
}

variable "database_default_ttl" {
  description = "Default TTL for database credentials in seconds"
  type        = number
  default     = 86400
}

variable "database_max_ttl" {
  description = "Maximum TTL for database credentials in seconds"
  type        = number
  default     = 259200
}

# -------------------------------------------------------------------------
# PKI CONFIGURATION
# -------------------------------------------------------------------------

variable "pki_backend_path" {
  description = "Path to the PKI secrets engine"
  type        = string
  default     = "pki_int"
}

variable "traefik_allowed_domains" {
  description = "Allowed domains for Traefik PKI role"
  type        = list(string)
  default     = ["munchbox.cc"]
}

variable "postgres_allowed_domains" {
  description = "Allowed domains for PostgreSQL PKI role"
  type        = list(string)
  default = [
    "postgres-primary.service.consul",
    "postgres-replica.service.consul",
    "postgres.service.consul",
    "node.consul"
  ]
}

# -------------------------------------------------------------------------
# POLICY CONFIGURATION
# -------------------------------------------------------------------------

variable "workload_secrets" {
  description = "List of secret paths that Nomad workloads can access"
  type        = list(string)
  default = [
    "traefik",
    "grafana",
    "backup-worker",
    "prometheus",
    "prometheus-nomad",
    "nomad-ui",
    "hashiuisecret",
    "alertmanager",
    "redis-shared",
    "postgres-shared/root",
    "postgres-shared/replication",
    "nextcloud",
    "deluge",
    "pia",
    "mullvad",
    "cloudflared",
    "vaultwarden",
    "temporal",
    "trivy-dashboard",
    "forgejo",
    "forgejo-runner",
    "umami",
    "s3-proxy",
    "patroni",
    "oauth2-proxy",
    "traefik-log-dashboard",
    "maxmind"
  ]
}
