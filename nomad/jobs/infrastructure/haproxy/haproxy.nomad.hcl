# -------------------------------------------------------------------------------
# HAProxy -- Database Failover Proxy
#
# Project: Munchbox / Author: Alex Freidah
#
# TCP proxy in front of Patroni (PostgreSQL) and Redis Sentinel. Health-checks
# Patroni REST API and Redis replication role to route traffic to the current
# primary. On failover, immediately terminates stale connections via
# on-marked-down shutdown-sessions, forcing apps to reconnect to the new primary.
#
# Backends are discovered dynamically via HAProxy DNS resolution against Consul DNS.
# -------------------------------------------------------------------------------

job "haproxy" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 75

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: haproxy
  #
  # Runs on goren and stabler alongside Patroni. Each instance independently
  # health-checks all backends and routes to the current primary. Consul
  # load-balances apps across both HAProxy instances.
  # ---------------------------------------------------------------------------

  group "haproxy" {
    count = 2

    # --- Spread across different nodes for HA ---
    spread {
      attribute = "${node.unique.name}"
      weight    = 100
    }

    # --- Prevent multiple instances on same node ---
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    # --- Run on ingress nodes only (meta.role=ingress) ---
    constraint {
      attribute = "${meta.role}"
      operator  = "="
      value     = "ingress"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
      port "postgres" {
        static = 5433
      }
      port "redis" {
        static = 6380
      }
      port "stats" {
        static = 8405
      }
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "10s"
      delay_function = "exponential"
      max_delay      = "2m"
      unlimited      = false
    }

    # --- PostgreSQL Proxy Service ---
    service {
      name     = "haproxy-postgres"
      port     = "postgres"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "postgres",
        "haproxy",
        "proxy"
      ]

      check {
        name     = "haproxy-postgres"
        type     = "tcp"
        port     = "postgres"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # --- Redis Proxy Service ---
    service {
      name     = "haproxy-redis"
      port     = "redis"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "redis",
        "haproxy",
        "proxy"
      ]

      check {
        name     = "haproxy-redis"
        type     = "tcp"
        port     = "redis"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # --- Stats and Metrics Service ---
    service {
      name     = "haproxy-stats"
      port     = "stats"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        # HTTPS router (direct LAN access)
        "traefik.http.routers.haproxy-stats.rule=Host(`haproxy.munchbox.cc`)",
        "traefik.http.routers.haproxy-stats.entrypoints=websecure",
        "traefik.http.routers.haproxy-stats.tls=true",
        "traefik.http.routers.haproxy-stats.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        # HTTP router (Cloudflare tunnel)
        "traefik.http.routers.haproxy-stats-http.rule=Host(`haproxy.munchbox.cc`)",
        "traefik.http.routers.haproxy-stats-http.entrypoints=web",
        "traefik.http.routers.haproxy-stats-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.services.haproxy-stats.loadbalancer.server.port=8405",
        "haproxy",
        "stats"
      ]

      check {
        name     = "haproxy-stats"
        type     = "http"
        port     = "stats"
        path     = "/stats"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # --- Metrics Service (for Prometheus) ---
    service {
      name     = "haproxy-metrics"
      port     = "stats"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "prometheus",
        "metrics",
        "haproxy"
      ]

      check {
        name     = "haproxy-metrics"
        type     = "http"
        port     = "stats"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: haproxy
    # -------------------------------------------------------------------------

    task "haproxy" {
      driver = "docker"

      # --- Vault Integration (for Redis password) ---
      vault {
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "haproxy:3.2-alpine"
        image_pull_timeout = "5m"
        network_mode       = "host"
        volumes = [
          "local/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro"
        ]
      }

      # --- HAProxy Configuration ---
      template {
        destination = "local/haproxy.cfg"
        change_mode = "restart"
        data        = <<-EOF
# HAProxy Configuration - Database Failover Proxy
# Backends discovered via Consul DNS, health-checked for primary role

global
    maxconn 1024
    log stdout format raw local0

# -----------------------------------------------------------------------
# Consul DNS Resolver
# -----------------------------------------------------------------------

resolvers consul
    nameserver consul 127.0.0.1:8600
    accepted_payload_size 8192
    # --- re-query fast when consul DNS goes empty (e.g. gossip-induced ---
    # --- check flap); without these the default hold caps recovery at ~30s ---
    hold valid    30s
    hold nx       5s
    hold obsolete 0s
    hold timeout  5s
    hold refused  5s
    resolve_retries 3
    timeout resolve 1s
    timeout retry 1s

defaults
    mode tcp
    timeout connect 5s
    timeout client 30m
    timeout server 30m
    timeout check 5s
    log global
    option tcplog
    option dontlognull

# -----------------------------------------------------------------------
# Stats and Prometheus Metrics
# -----------------------------------------------------------------------

frontend stats
    mode http
    bind *:{{ env "NOMAD_PORT_stats" }}
    no log
    http-request use-service prometheus-exporter if { path /metrics }
    stats enable
    stats uri /stats
    stats refresh 10s

# -----------------------------------------------------------------------
# PostgreSQL - Routes to Patroni primary via REST API health check
# -----------------------------------------------------------------------

frontend postgres_frontend
    bind *:{{ env "NOMAD_PORT_postgres" }}
    default_backend postgres_backend

backend postgres_backend
    option httpchk GET /primary
    http-check expect status 200
    default-server inter 10s fall 3 rise 2 on-marked-down shutdown-sessions
    server-template pg 2 patroni.service.consul:5432 resolvers consul resolve-prefer ipv4 check port 8008 init-addr none

# -----------------------------------------------------------------------
# Redis - Routes to Redis master via replication role check
# -----------------------------------------------------------------------

frontend redis_frontend
    bind *:{{ env "NOMAD_PORT_redis" }}
    default_backend redis_backend

backend redis_backend
    option tcp-check
    tcp-check connect
    tcp-check send "AUTH {{ with secret "secret/data/redis-shared" }}{{ .Data.data.password }}{{ end }}\r\n"
    tcp-check expect string +OK
    tcp-check send "PING\r\n"
    tcp-check expect string +PONG
    tcp-check send "info replication\r\n"
    tcp-check expect string role:master
    tcp-check send "QUIT\r\n"
    tcp-check expect string +OK
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server-template redis 2 redis.service.consul:6379 resolvers consul resolve-prefer ipv4 check init-addr none
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 200
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }
  }
}
