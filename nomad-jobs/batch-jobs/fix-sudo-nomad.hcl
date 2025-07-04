job "fix-sudo-docker" {
  datacenters = ["pi-dc"]   # --- Nomad datacenter(s) to run in ---
  type        = "batch"     # --- Batch job type ---

  group "fix" {
    task "fix-sudo" {
      driver = "docker"     # --- Use Docker driver ---

      config {
        image      = "busybox"                                                           # --- BusyBox image ---
        command    = "/bin/sh"                                                           # --- Shell command ---
        args       = ["-c", "chown root:root /usr/bin/sudo && chmod 4755 /usr/bin/sudo"] # --- Fix sudo permissions ---
        # nosemgrep: avoid-privileged
        privileged = true                                                                # --- Run as privileged ---
        volumes               = [
          "/usr/bin:/usr/bin" # --- Mount host /usr/bin ---
        ]
      }

      resources {
        cpu    = 10    # --- Minimal CPU ---
        memory = 16    # --- Minimal memory ---
      }
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "pi-98" # --- Only run on node pi-98 ---
    }
  }
}
