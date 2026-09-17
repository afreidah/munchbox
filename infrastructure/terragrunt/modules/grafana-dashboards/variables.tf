# -----------------------------------------------------------------------------
# GRAFANA-DASHBOARDS Module Variables
# -----------------------------------------------------------------------------

variable "grafana_url" {
  description = "Grafana base URL the provider calls (internal, no TLS, bypasses oauth2-proxy)."
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin username; sourced from TF_VAR_grafana_admin_user via env_helper."
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password; sourced from TF_VAR_grafana_admin_password via env_helper."
  type        = string
  sensitive   = true
}

variable "folder_uid" {
  description = "Grafana folder UID that owns every managed dashboard. Must already exist."
  type        = string
  default     = "munchbox-folder"
}

variable "dashboards_dir" {
  description = "Absolute path to a directory of dashboard JSON files. One grafana_dashboard resource is created per *.json found there. JSON bodies are loaded lazily with file() to avoid blowing the TF_VAR env-size limit."
  type        = string
}

variable "remote_dashboards" {
  description = "Dashboards fetched from an artifact store rather than read off disk, keyed by the slug they get in Grafana. Each names the bucket and the versioned object holding its JSON. A slug present here and in dashboards_dir resolves to the remote body."
  type = map(object({
    bucket = string
    key    = string
  }))
  default  = {}
  nullable = false
}

variable "artifact_store" {
  description = "S3-compatible endpoint the remote dashboards are read from."
  type = object({
    endpoint   = string
    access_key = string
    secret_key = string
    region     = optional(string, "us-east-1")
  })
  sensitive = true
  nullable  = false
}
