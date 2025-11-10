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
