# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS Module Variables
# -----------------------------------------------------------------------------

variable "groups" {
  description = "Map of Consul KV path (e.g. prometheus/alerts/postgresql-health, loki/alerts/log-infrastructure) to the rendered YAML body for that alert group. One key per group; the consuming job's consul-template watches the prefix and concatenates."
  type        = map(string)

  validation {
    condition     = alltrue([for k in keys(var.groups) : can(regex("^[a-z0-9-]+/alerts/[a-z0-9-]+$", k))])
    error_message = "Every group key must be <system>/alerts/<group> so the consuming job's KV-prefix watch picks it up."
  }
}

variable "datacenter" {
  description = "Consul datacenter to write keys into. Defaults to the provider default."
  type        = string
  default     = null
}
