###############################################################################
# Vault — Nomad Job
# - Runs Vault server in dev or HA mode (adjust as needed)
# - Persists data to host volume for durability
# - Exposes HTTP API on port 8200
# - Registers with Consul for service discovery
###############################################################################

job "vault" {
  datacenters = ["pi-dc"]
  type        = "service"

  update {
    healthy_deadline  = "9m"
    progress_deadline = "10m"
  }

  group "vault" {
    count = 1  # For HA, deploy more than one and configure cluster join

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "pi-222"
    }

    network {
      port "http" {
        static = 8200
      }
    }

    volume "vault-data" {
      type      = "host"
      source    = "vault-data"
      read_only = false
    }

    task "vault" {
      driver            = "docker"

      config {
        image = "192.168.1.115:5000/my-vault-arm6:latest"
        force_pull = false
        image_pull_timeout = "30m"
        ports = ["http"]
        args  = [
          "server",
          "-config=/vault/config/vault.hcl"
        ]
        volumes = [
          "local/vault.hcl:/vault/config/vault.hcl",
          "vault-data:/vault/file"
        ]
        cap_add = ["IPC_LOCK"]
      }

      env {
        VAULT_LOCAL_CONFIG = <<EOH
          ui = true
          listener "tcp" {
            address     = "0.0.0.0:8200"
            tls_disable = 1
          }
          storage "file" {
            path = "/vault/file"
          }
        EOH
        VAULT_ADDR = "http://127.0.0.1:8200"
      }

      service {
        name       = "vault"
        port       = "http"
        provider   = "consul"

        check {
          name     = "http"
          type     = "http"
          path     = "/v1/sys/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        destination = "local/vault.hcl"
        perms       = "0644"
        change_mode = "restart"
        data = <<-EOF
          ui = true

          listener "tcp" {
            address     = "0.0.0.0:8200"
            tls_disable = 1
          }

          storage "file" {
            path = "/vault/file"
          }
        EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

