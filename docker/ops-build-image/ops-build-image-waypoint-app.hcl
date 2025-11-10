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
