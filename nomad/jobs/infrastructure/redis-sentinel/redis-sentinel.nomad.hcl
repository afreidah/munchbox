# -------------------------------------------------------------------------------
# Redis Sentinel — High Availability Redis Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Redis with Sentinel for automatic failover. Runs 2 Redis instances (master +
# replica) with 3 Sentinels for quorum. Replaces redis-shared with HA cluster.
# -------------------------------------------------------------------------------

job "redis-sentinel" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "all"
  priority    = 80

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
    health_check      = "task_states"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: redis
  #
  # Runs Redis + Sentinel on 2 nodes. First node becomes master, second replica.
  # Sentinel handles automatic failover.
  # ---------------------------------------------------------------------------

  group "redis" {
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

    # --- Keep Redis on bare metal nodes (not Oracle Cloud nodes over WireGuard) ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "set_contains_any"
      value     = "stabler,goren,nomad-server-03,nomad-client-01,nomad-client-02,nomad-client-03,nomad-client-04,nomad-client-05"
    }

    # --- Network Configuration ---
    network {
      mode = "host"
      port "redis" {
        static = 6379
      }
      port "sentinel" {
        static = 26379
      }
      port "metrics" {
        static = 9121
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

    # --- Primary Service (only healthy on master) ---
    service {
      name     = "redis-primary"
      port     = "redis"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "redis",
        "primary",
        "sentinel"
      ]

      check {
        name     = "redis-master-check"
        type     = "script"
        task     = "redis"
        command  = "/bin/sh"
        args     = ["-c", "redis-cli -a $REDIS_PASSWORD INFO replication 2>/dev/null | grep -q 'role:master' || exit 2"]
        interval = "5s"
        timeout  = "3s"
      }
    }

    # --- Replica Service (only healthy on replicas) ---
    service {
      name     = "redis-replica"
      port     = "redis"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "redis",
        "replica",
        "read-only",
        "sentinel"
      ]

      check {
        name     = "redis-replica-check"
        type     = "script"
        task     = "redis"
        command  = "/bin/sh"
        args     = ["-c", "redis-cli -a $REDIS_PASSWORD INFO replication 2>/dev/null | grep -q 'role:slave' || exit 2"]
        interval = "5s"
        timeout  = "3s"
      }
    }

    # --- Sentinel Service ---
    service {
      name     = "redis-sentinel"
      port     = "sentinel"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "redis",
        "sentinel"
      ]

      check {
        name     = "sentinel-health"
        type     = "tcp"
        port     = "sentinel"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # --- Redis Metrics (for Prometheus) ---
    service {
      name     = "redis-exporter"
      port     = "metrics"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "prometheus",
        "metrics",
        "redis"
      ]

      check {
        name     = "redis-exporter-health"
        type     = "http"
        port     = "metrics"
        path     = "/metrics"
        interval = "30s"
        timeout  = "5s"
      }
    }

    # -------------------------------------------------------------------------
    # Task: init-storage
    # -------------------------------------------------------------------------

    task "init-storage" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:1.37.0"
        command = "sh"
        args    = ["-c", "mkdir -p /data/redis /data/sentinel && rm -f /data/sentinel/sentinel.conf && chown -R 999:999 /data && chmod 700 /data/redis /data/sentinel"]
        volumes = ["/opt/nomad/data/redis-${NOMAD_ALLOC_INDEX}:/data"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # -------------------------------------------------------------------------
    # Task: redis
    # -------------------------------------------------------------------------

    task "redis" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "redis:8-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        command            = "redis-server"
        args               = ["/etc/redis/redis.conf"]

        volumes = [
          "/opt/nomad/data/redis-${NOMAD_ALLOC_INDEX}/redis:/data",
          "local/redis.conf:/etc/redis/redis.conf:ro"
        ]
      }

      # --- Redis Configuration ---
      template {
        destination = "local/redis.conf"
        change_mode = "restart"
        data        = <<-EOF
# Redis Sentinel Configuration
bind 0.0.0.0
port {{ env "NOMAD_PORT_redis" }}
dir /data

# Authentication
{{ with secret "secret/data/redis-shared" }}
requirepass {{ .Data.data.password }}
masterauth {{ .Data.data.password }}
{{ end }}

# Persistence
save 60 1
appendonly yes
appendfsync everysec

# Memory
maxmemory 512mb
maxmemory-policy allkeys-lru

# Logging
loglevel warning

# Replication - first allocation (index 0) is initial master, others replicate via Consul
# Sentinel handles failover if master goes down
{{ if ne (env "NOMAD_ALLOC_INDEX") "0" }}
replicaof redis-primary.service.consul 6379
{{ end }}
        EOF
      }

      # --- Environment ---
      template {
        destination = "secrets/redis.env"
        env         = true
        data        = <<-EOF
{{ with secret "secret/data/redis-shared" }}
REDIS_PASSWORD={{ .Data.data.password }}
{{ end }}
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 200
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }

    # -------------------------------------------------------------------------
    # Task: sentinel
    # -------------------------------------------------------------------------

    task "sentinel" {
      driver = "docker"

      # --- Vault Integration ---
      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Docker Configuration ---
      config {
        image              = "redis:8-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        dns_servers        = ["192.168.68.71"]
        command            = "/bin/sh"
        args               = ["-c", "cp /etc/sentinel/sentinel.conf.tpl /data/sentinel.conf && redis-sentinel /data/sentinel.conf"]

        volumes = [
          "/opt/nomad/data/redis-${NOMAD_ALLOC_INDEX}/sentinel:/data",
          "local/sentinel.conf:/etc/sentinel/sentinel.conf.tpl:ro"
        ]
      }

      # --- Sentinel Configuration ---
      template {
        destination = "local/sentinel.conf"
        change_mode = "restart"
        data        = <<-EOF
# Sentinel Configuration
port {{ env "NOMAD_PORT_sentinel" }}
dir /data
daemonize no

# Monitor the Redis master
# ALLOC_INDEX=0 is the initial master, so monitor locally
# Other allocations monitor via Consul once master is healthy
{{ with secret "secret/data/redis-shared" }}
{{ if eq (env "NOMAD_ALLOC_INDEX") "0" }}
sentinel monitor munchbox-redis 127.0.0.1 6379 2
{{ else }}
sentinel monitor munchbox-redis redis-primary.service.consul 6379 2
{{ end }}
sentinel auth-pass munchbox-redis {{ .Data.data.password }}
{{ end }}

# Timing settings
sentinel down-after-milliseconds munchbox-redis 5000
sentinel failover-timeout munchbox-redis 60000
sentinel parallel-syncs munchbox-redis 1

# Announce settings for proper discovery
sentinel announce-ip {{ env "NOMAD_IP_sentinel" }}
sentinel announce-port {{ env "NOMAD_PORT_sentinel" }}
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 100
        memory = 64
      }

      # --- Termination ---
      kill_timeout = "10s"
      kill_signal  = "SIGTERM"
    }

    # -------------------------------------------------------------------------
    # Task: redis-exporter (Prometheus metrics sidecar)
    # -------------------------------------------------------------------------

    task "redis-exporter" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "oliver006/redis_exporter:v1.66.0"
        network_mode = "host"
      }

      template {
        destination = "secrets/exporter.env"
        env         = true
        data        = <<-EOF
{{ with secret "secret/data/redis-shared" }}
REDIS_ADDR=redis://127.0.0.1:{{ env "NOMAD_PORT_redis" }}
REDIS_PASSWORD={{ .Data.data.password }}
{{ end }}
REDIS_EXPORTER_WEB_LISTEN_ADDRESS=:{{ env "NOMAD_PORT_metrics" }}
REDIS_EXPORTER_CHECK_KEYS=*
REDIS_EXPORTER_INCL_SYSTEM_METRICS=true
        EOF
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task Group: sentinel-quorum
  #
  # Additional sentinel to ensure quorum of 3. Runs standalone without Redis.
  # ---------------------------------------------------------------------------

  group "sentinel-quorum" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "sentinel" {
        static = 26380
      }
    }

    # --- Service ---
    service {
      name     = "redis-sentinel"
      port     = "sentinel"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "redis",
        "sentinel",
        "quorum"
      ]

      check {
        name     = "sentinel-quorum-health"
        type     = "tcp"
        port     = "sentinel"
        interval = "10s"
        timeout  = "3s"
      }
    }

    # --- Task: sentinel ---
    task "sentinel" {
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
        image              = "redis:8-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        dns_servers        = ["192.168.68.71"]
        command            = "/bin/sh"
        args               = ["-c", "echo 'Waiting for redis-primary.service.consul...'; while ! getent hosts redis-primary.service.consul >/dev/null 2>&1; do sleep 2; done; echo 'Master found, starting sentinel'; cp /etc/sentinel/sentinel.conf.tpl /tmp/sentinel.conf && redis-sentinel /tmp/sentinel.conf"]

        volumes = [
          "local/sentinel.conf:/etc/sentinel/sentinel.conf.tpl:ro"
        ]
      }

      template {
        destination = "local/sentinel.conf"
        change_mode = "restart"
        data        = <<-EOF
# Sentinel Quorum Configuration (standalone - no local Redis)
port {{ env "NOMAD_PORT_sentinel" }}
dir /tmp
daemonize no

# Monitor the Redis master via Consul service discovery
{{ with secret "secret/data/redis-shared" }}
sentinel monitor munchbox-redis redis-primary.service.consul 6379 2
sentinel auth-pass munchbox-redis {{ .Data.data.password }}
{{ end }}

sentinel down-after-milliseconds munchbox-redis 5000
sentinel failover-timeout munchbox-redis 60000
sentinel parallel-syncs munchbox-redis 1

sentinel announce-ip {{ env "NOMAD_IP_sentinel" }}
sentinel announce-port {{ env "NOMAD_PORT_sentinel" }}
        EOF
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}
