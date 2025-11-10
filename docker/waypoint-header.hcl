# ═══════════════════════════════════════════════════════════════════════════
# Waypoint Configuration - Munchbox Docker Images
# ═══════════════════════════════════════════════════════════════════════════
# Auto-generated from waypoint-header.hcl + */waypoint-app.hcl
#
# Usage:
#   ./build.sh                    # Build all images
#   ./build.sh -app ops-build-image  # Build specific image
#
# ═══════════════════════════════════════════════════════════════════════════

project = "munchbox-docker"

variable "registry_host" {
  type        = string
  description = "Docker registry hostname"
  default     = "docker-mirror.service.consul"
}

variable "registry_port" {
  type        = number
  description = "Docker registry port"
  default     = 5000
}

variable "git_ref" {
  type        = string
  description = "Git ref for tagging"
  default     = "latest"
}
