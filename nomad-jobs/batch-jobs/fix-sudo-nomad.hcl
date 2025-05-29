job "fix-sudo-docker" {
  datacenters = ["pi-dc"]
  type        = "batch"
  group "fix" {
    task "fix-sudo" {
      driver = "docker"
      config {
        image = "busybox"
        command = "/bin/sh"
        args = ["-c", "chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo"]
        privileged = true
        volumes = [
          "/usr/bin:/usr/bin"
        ]
      }
      resources {
        cpu    = 10
        memory = 16
      }
    }
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "pi-98"
    }
  }
}

