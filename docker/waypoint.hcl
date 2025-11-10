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

# Project: Munchbox
# Application: deluge-vpn
# Purpose: Torrent client with VPN tunnel

app "deluge-vpn" {
  build {
    use "docker" {
      buildkit   = true
      context    = "./deluge-vpn"
      dockerfile = "./deluge-vpn/Dockerfile"
    }
  }

  deploy {
    use "null" {}
  }

  release {
    use "docker" {
      tag = "${var.registry_host}:${var.registry_port}/deluge-vpn:${var.git_ref}"
    }
  }
}
# Project: Munchbox
# Application: github-runner-waypoint
# Purpose: GitHub Actions runner with Waypoint CLI for self-hosted execution

app "github-runner-waypoint" {
  build {
    use "docker" {
      buildkit   = true
      context    = "./github-runner-waypoint"
      dockerfile = "./github-runner-waypoint/Dockerfile"
    }
  }

  deploy {
    use "null" {}
  }

  release {
    use "docker" {
      tag = "${var.registry_host}:${var.registry_port}/github-runner-waypoint:${var.git_ref}"
    }
  }
}
# Project: Munchbox
# Application: ops-build-image
# Purpose: Infrastructure toolchain with Terraform, Go, Node.js, security tools

app "ops-build-image" {
  build {
    use "docker" {
      buildkit   = true
      context    = "./ops-build-image"
      dockerfile = "./ops-build-image/Dockerfile"
    }
  }

  deploy {
    use "null" {}
  }

  release {
    use "docker" {
      tag = "${var.registry_host}:${var.registry_port}/ops-build-image:${var.git_ref}"
    }
  }
}
# Project: Munchbox
# Application: ops-waypoint-image
# Purpose: Waypoint server with operations tooling

app "ops-waypoint-image" {
  build {
    use "docker" {
      buildkit   = true
      context    = "./ops-waypoint-image"
      dockerfile = "./ops-waypoint-image/Dockerfile"
    }
  }

  deploy {
    use "null" {}
  }

  release {
    use "docker" {
      tag = "${var.registry_host}:${var.registry_port}/ops-waypoint-image:${var.git_ref}"
    }
  }
}
