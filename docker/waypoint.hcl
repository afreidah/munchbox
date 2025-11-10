# Waypoint build
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
