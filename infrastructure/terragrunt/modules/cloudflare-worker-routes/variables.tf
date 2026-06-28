# -----------------------------------------------------------------------------
# CLOUDFLARE-WORKER-ROUTES MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare token with Workers Scripts + Routes write."
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account id that owns the Worker script."
  type        = string
}

variable "script_name" {
  description = "Name of the Worker script."
  type        = string
}

variable "content" {
  description = "Worker script source (ES module exporting a default fetch handler)."
  type        = string
}

variable "main_module" {
  description = "Filename of the script's main module (ES module syntax)."
  type        = string
  default     = "worker.js"
}

variable "compatibility_date" {
  description = "Workers runtime compatibility date."
  type        = string
  default     = "2025-01-01"
}

variable "routes" {
  description = "Map of route pattern => zone_id; one cloudflare_workers_route per entry binds the script to that pattern."
  type        = map(string)
  default     = {}
}
