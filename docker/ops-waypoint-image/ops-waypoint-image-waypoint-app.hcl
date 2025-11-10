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
