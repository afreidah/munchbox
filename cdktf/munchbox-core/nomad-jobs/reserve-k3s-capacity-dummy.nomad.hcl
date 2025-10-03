# --------------------------------------------------------------------
# Nomad “reservation” job — so the scheduler won’t overcommit this node
# --------------------------------------------------------------------
job "reserve-k3s-capacity" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "hold" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "goren"
    }

    task "sleep" {
      driver = "raw_exec"
      config {
        command = "/bin/bash"
        args    = ["-c", "trap : TERM INT; sleep infinity & wait"]
      }

      # --------------------------------------------------------------------
      # Reserve ~4 vCPU and 4 GB RAM for the dummy placeholder job
      # --------------------------------------------------------------------
      resources {
        cpu    = 4000   # ≈ 4 vCPU worth of scheduler shares
        memory = 4096   # 4 GB (MB units)
      }
    }
  }
}
