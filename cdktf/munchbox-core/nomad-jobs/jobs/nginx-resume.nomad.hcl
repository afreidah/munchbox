# ------------------------------------------------------------------------------
# Nginx Static Site — Serve prebuilt HTML from Nomad host_volume on mccoy
# ------------------------------------------------------------------------------

job "nginx-resume-hostfile" {
  region      = "global"
  datacenters = ["pi-dc"]
  node_pool   = "core"
  type        = "service"

  group "web" {
    count = 1

    # Force this to run on mccoy (your ingress node)
    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "mccoy"
    }

    # host_volume declared in Nomad client config:
    # client {
    #   host_volume "nginx-resume" {
    #     path      = "/opt/nomad/data/nginx-resume"
    #     read_only = true
    #   }
    # }

    volume "site" {
      type      = "host"
      source    = "nginx-resume"
      read_only = true
    }

    network {
      port "http" {
        to     = 80
        static = 8080   # host:8080 -> container:80
      }
    }

    task "nginx" {
      driver = "docker"
      config {
        image  = "nginx:stable"
        ports  = ["http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro"
        ]
      }

      volume_mount {
        volume      = "site"
        destination = "/usr/share/nginx/html"
        read_only   = true
      }

      # minimal server: prefer resume.html
      template {
        destination = "local/default.conf"
        data = <<-EOT
          server {
            listen 80;
            server_name _;
            root /usr/share/nginx/html;
            index resume.html index.html;
            location / {
              try_files /resume.html $uri $uri/ =404;
            }
          }
        EOT
      }

      resources {
        cpu    = 200
        memory = 128
      }

      service {
        name = "nginx-resume"
        port = "http"
        check {
          type     = "http"
          path     = "/resume.html"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
