# -----------------------------------------------------------------------------
# PIHOLE-CONFIG MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "pihole_primary_url" {
  description = "URL for the primary (green) Pi-hole."
  type        = string
}

variable "pihole_secondary_url" {
  description = "URL for the secondary (logan) Pi-hole."
  type        = string
}

variable "pihole_password_primary" {
  description = "Primary Pi-hole password; sourced from TF_VAR_pihole_password_primary."
  type        = string
  sensitive   = true
}

variable "pihole_password_secondary" {
  description = "Secondary Pi-hole password; sourced from TF_VAR_pihole_password_secondary."
  type        = string
  sensitive   = true
}

variable "max_db_days" {
  description = "FTL query DB retention in days."
  type        = number
}

variable "db_interval" {
  description = "FTL DB flush interval in seconds."
  type        = number
}

variable "use_wal" {
  description = "Enable SQLite WAL mode for FTL's query db."
  type        = bool
}

variable "parse_arp_cache" {
  description = "Whether FTL parses the ARP table periodically."
  type        = bool
}

variable "privacy_level" {
  description = "FTL privacy level (0=show all, 3=hide all)."
  type        = number
}

variable "cache_size" {
  description = "dnsmasq DNS cache size (entries)."
  type        = number
}

variable "query_logging" {
  description = "Whether FTL logs individual queries."
  type        = bool
}

variable "dnssec" {
  description = "Whether pihole performs DNSSEC validation (off when upstream unbound already does it)."
  type        = bool
}

variable "expand_hosts" {
  description = "Append domain_name to /etc/hosts entries when serving DNS."
  type        = bool
}

variable "interface" {
  description = "Interface pihole listens on; empty means all interfaces."
  type        = string
}

variable "domain_name" {
  description = "Local domain suffix used when expand_hosts is true."
  type        = string
}

variable "etc_dnsmasq_d" {
  description = "Whether pihole-FTL reads custom configs from /etc/dnsmasq.d/. Must be true for pihole-files snippets."
  type        = bool
}

variable "upstream" {
  description = "Single upstream DNS the pihole forwards to."
  type        = string
}
