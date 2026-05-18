# -------------------------------------------------------------------------------
# gitgogit — Git Repository Mirroring Daemon
#
# Project: Munchbox / Author: Alex Freidah
#
# Mirrors GitHub repositories to the local Forgejo instance. Runs the daemon
# with a web dashboard for status monitoring and manual sync triggers.
# -------------------------------------------------------------------------------

job "gitgogit" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 40

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: gitgogit
  # ---------------------------------------------------------------------------

  group "gitgogit" {
    count = 1

    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "oraclenode1"
    }

    constraint {
      attribute = "${node.unique.name}"
      operator  = "!="
      value     = "oraclenode2"
    }

    network {
      port "http" {
        to = 8080
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    service {
      name     = "gitgogit"
      port     = "http"
      provider = "consul"

      tags = [
        "infrastructure",
        "git-mirror",
        "traefik.enable=true",
        "traefik.http.routers.gitgogit.rule=Host(`gitgogit.munchbox.cc`)",
        "traefik.http.routers.gitgogit.entrypoints=websecure",
        "traefik.http.routers.gitgogit.tls=true",
        "traefik.http.routers.gitgogit.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.routers.gitgogit-http.rule=Host(`gitgogit.munchbox.cc`)",
        "traefik.http.routers.gitgogit-http.entrypoints=web",
        "traefik.http.routers.gitgogit-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
      ]

      check {
        name      = "healthz"
        type      = "http"
        path      = "/healthz"
        interval  = "30s"
        timeout   = "5s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: gitgogit
    # -------------------------------------------------------------------------

    task "gitgogit" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "registry.munchbox.cc/gitgogit:v0.2.0"
        image_pull_timeout = "5m"
        ports              = ["http"]
        volumes            = [
          "local/config.yaml:/home/gitgogit/.config/gitgogit/config.yaml:ro",
        ]
      }

      template {
        data = <<-EOF
        {{ with secret "secret/data/forgejo" }}
        FORGEJO_API_TOKEN={{ .Data.data.api_token }}
        {{ end }}
        EOF
        destination = "secrets/secrets.env"
        env         = true
      }

      template {
        data        = <<-EOF
repos:
  - name: munchbox
    source:
      url: https://github.com/afreidah/munchbox.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/munchbox.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN

  - name: s3-orchestrator
    source:
      url: https://github.com/afreidah/s3-orchestrator.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/s3-orchestrator.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN

  - name: gitgogit
    source:
      url: https://github.com/afreidah/gitgogit.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/gitgogit.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN
          
  - name: flight-fetcher
    source:
      url: https://github.com/afreidah/flight-fetcher.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/flight-fetcher.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN

  - name: cloudflare-log-collector
    source:
      url: https://github.com/afreidah/cloudflare-log-collector.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/cloudflare-log-collector.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN
  - name: oracle-watchdog
    source:
      url: https://github.com/afreidah/oracle-watchdog.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/oracle-watchdog.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN
  - name: nomad-temporal-jobs
    source:
      url: https://github.com/afreidah/nomad-temporal-jobs.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/nomad-temporal-jobs.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN
  - name: health-checker
    source:
      url: https://github.com/afreidah/health-check-service.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/health-checker.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN
  - name: g3
    source:
      url: https://github.com/afreidah/g3.git
    mirrors:
      - url: http://forgejo.service.consul:30028/alex/g3.git
        push_strategy: branches+tags
        force: true
        auth:
          type: token
          env: FORGEJO_API_TOKEN

daemon:
  interval: 30m
  log_file: /dev/stdout
  web:
    enabled: true
    listen: ":8080"
        EOF
        destination = "local/config.yaml"
        change_mode = "restart"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }

  meta = {
    project = "munchbox"
  }
}
