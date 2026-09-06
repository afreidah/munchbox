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

variable "transit_enabled" {
  description = "Enable Transit secrets engine for encryption and signing"
  type        = bool
  default     = false
}

variable "ssh_ca_enabled" {
  description = "Enable SSH certificate authority for host and client signing"
  type        = bool
  default     = false
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
  description = "Map of database roles to create with their creation statements"
  type = map(object({
    creation_statements = list(string)
    default_ttl         = optional(number, 86400)
    max_ttl             = optional(number, 259200)
  }))
  default = {}
}

# -------------------------------------------------------------------------
# PKI CONFIGURATION
# -------------------------------------------------------------------------

variable "pki_backend_path" {
  description = "Path to the PKI secrets engine"
  type        = string
  default     = "pki_int"
}

variable "pki_roles" {
  description = "Map of PKI roles to create"
  type = map(object({
    allowed_domains             = list(string)
    allow_any_name              = optional(bool, false)
    allow_subdomains            = optional(bool, true)
    allow_bare_domains          = optional(bool, true)
    allow_localhost             = optional(bool, true)
    allow_ip_sans               = optional(bool, true)
    allow_glob_domains          = optional(bool, false)
    allow_wildcard_certificates = optional(bool, true)
    enforce_hostnames           = optional(bool, true)
    client_flag                 = optional(bool, true)
    server_flag                 = optional(bool, true)
    max_ttl                     = optional(string, "8760h")
    ttl                         = optional(string, "720h")
    key_type                    = optional(string, "rsa")
    key_bits                    = optional(number, 4096)
    require_cn                  = optional(bool, false)
    # --- which identities may issue this role; drives policy generation (not a Vault field) ---
    issued_by = optional(list(string), [])
  }))
  default = {}
}

# -------------------------------------------------------------------------
# POLICY CONFIGURATION
# -------------------------------------------------------------------------

variable "workload_secrets" {
  description = "List of secret paths that Nomad workloads can access"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------
# APPROLE AUTH (chef-managed nodes)
# -------------------------------------------------------------------------

variable "approle_auth_enabled" {
  description = "Enable AppRole auth backend for chef-managed nodes"
  type        = bool
  default     = false
}

variable "chef_managed_node_secrets" {
  description = "KV v2 paths (sans `secret/data/` prefix) that chef-managed nodes can read. Globs supported (* matches trailing characters, + matches one path segment)."
  type        = list(string)
  default     = []
}

variable "chef_managed_node_extra_paths" {
  description = "Non-KV Vault paths chef-managed nodes can hit (e.g. ssh-client-signer/config/ca). Each entry takes a `path` (literal Vault path) + `capabilities` list. Use this for SSH signer pubkeys, transit reads, or any backend that doesn't live under `secret/data/`."
  type = list(object({
    path         = string
    capabilities = list(string)
  }))
  default = []
}

variable "vault_policies" {
  description = "Map of Vault policies to create"
  type = map(object({
    policy = string
  }))
  default = {}
}

# -------------------------------------------------------------------------
# WORKLOAD VAULT ROLES
# -------------------------------------------------------------------------

variable "workload_extra_secrets" {
  description = "Nomad job id -> the grants it needs beyond its own secret/data/<job id> prefix. secrets are KV names granted read; extra_paths maps a full Vault path to its capabilities. Each entry generates a <job>-secrets policy."
  type = map(object({
    secrets     = optional(list(string), [])
    extra_paths = optional(map(list(string)), {})
  }))
  default = {}
}

variable "workload_vault_roles" {
  description = "Map of dedicated JWT auth roles for specific Nomad workloads"
  type = map(object({
    policies     = list(string)
    bound_claims = optional(map(string), {})
    token_ttl    = optional(number, 3600)
    # --- 0 = renewable forever, matching the default nomad-workloads role. A
    #     finite max_ttl makes renewal impossible once it elapses: nomad kills
    #     the task on the failed renew, so every job on this role dies on a
    #     fixed clock from whenever its alloc started. See the rationale at
    #     main.tf:90 on vault_jwt_auth_backend_role.nomad. ---
    token_max_ttl = optional(number, 0)
  }))
  default = {}
}

# -------------------------------------------------------------------------
# SERVICE TOKENS
# -------------------------------------------------------------------------

variable "service_tokens" {
  description = "Map of service tokens to create and store in KV"
  type = map(object({
    policies   = list(string)
    vault_path = string
    ttl        = optional(string, "8760h")
    renewable  = optional(bool, true)
    extra_data = optional(map(string), {})
  }))
  default = {}
}
