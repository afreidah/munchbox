# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS Module Variables
# -----------------------------------------------------------------------------

variable "groups" {
  description = "Map of Consul KV path (e.g. prometheus/alerts/postgresql-health) to the rendered YAML body for that alert group. One key per group; the prometheus job's consul-template watches the prefix and concatenates."
  type        = map(string)

  validation {
    condition     = alltrue([for k in keys(var.groups) : startswith(k, "prometheus/alerts/")])
    error_message = "Every group key must start with prometheus/alerts/ so the prometheus job's KV-prefix watch picks it up."
  }
}

variable "datacenter" {
  description = "Consul datacenter to write keys into. Defaults to the provider default."
  type        = string
  default     = null
}
