# -----------------------------------------------------------------------------
# JELLYFIN-CONFIG MODULE - VARIABLES
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER CONNECTION
# -----------------------------------------------------------------------------

variable "jellyfin_endpoint" {
  description = "Jellyfin server base URL (e.g. http://host:8096); sourced from TF_VAR_jellyfin_endpoint via the env_helper."
  type        = string
}

variable "jellyfin_api_key" {
  description = "Jellyfin API key; sourced from TF_VAR_jellyfin_api_key via the env_helper."
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SINGLETON CONFIGURATIONS
# -----------------------------------------------------------------------------
# --- Each is the provider's configuration_json verbatim; the env_helper
#     json-encodes the settings object from root.hcl (null = unmanaged). The
#     concrete jellyfin keys live in root.hcl, not in this module. ---

variable "encoding_configuration_json" {
  description = "Encoding/transcoding settings as a JSON string for jellyfin_encoding_configuration. null = unmanaged."
  type        = string
  default     = null
}

variable "livetv_configuration_json" {
  description = "Live TV settings (tuner hosts + listing providers) as a JSON string for jellyfin_livetv_configuration. null = unmanaged."
  type        = string
  default     = null
}

variable "system_configuration_json" {
  description = "System settings as a JSON string for jellyfin_system_configuration. null = unmanaged."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# SCHEDULED TASKS
# -----------------------------------------------------------------------------

variable "scheduled_tasks" {
  description = "Map of Jellyfin scheduled tasks to manage; map key is the Terraform state key. triggers_json is the provider's triggers_json (a JSON array) verbatim."
  type = map(object({
    task_id       = string
    triggers_json = string
  }))
  default = {}
}
