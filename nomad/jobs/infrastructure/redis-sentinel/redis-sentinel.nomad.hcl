# -------------------------------------------------------------------------------
# Redis Sentinel — High Availability Redis Cluster
#
# Project: Munchbox / Author: Alex Freidah
#
# Redis with Sentinel for automatic failover. Runs 2 Redis instances with 3
# Sentinels for quorum. On cold boot, alloc index 0 becomes master and the
# other alloc replicates it; on any restart each instance asks Sentinel for
# the current master and replicates it, so a reschedule never leaves two
# standalone masters. Sentinel monitors the redis-primary service (healthy
# only on the real master) and handles failover.
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

    # --- Keep Redis off the ingress nodes. Patroni is constrained to
    # meta.role=ingress, so without this the Redis master and the Postgres
    # primary drift onto the same host and one node loss takes both, plus
    # traefik/keepalived and the monitoring that would report it. ---
    constraint {
      attribute = "${meta.role}"
      operator  = "!="
      value     = "ingress"
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

    # --- Generic Redis Service (for bootstrap discovery) ---
    service {
      name     = "redis"
      port     = "redis"
      provider = "consul"

      tags = [
        "traefik.enable=false",
        "database",
        "redis"
      ]

      check {
        name     = "redis-tcp"
        type     = "tcp"
        port     = "redis"
        interval = "10s"
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
        image   = "busybox:1.38.0"
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
      # WI token re-derives at the role's max_ttl; noop so that token cycle
      # does not restart redis (a restart = a sentinel failover, and the
      # replica bounces seconds later inside the same failover-timeout).
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
        image              = "redis:8.8.0-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        command            = "/bin/sh"
        args               = ["-c", "sh /etc/redis/bootstrap.sh"]

        volumes = [
          "/opt/nomad/data/redis-${NOMAD_ALLOC_INDEX}/redis:/data",
          "local/redis.conf:/etc/redis/redis.conf.tpl:ro",
          "local/bootstrap.sh:/etc/redis/bootstrap.sh:ro"
        ]
      }

      # --- Redis Configuration ---
      # No replicaof in the template itself; bootstrap.sh appends one at
      # startup after asking Sentinel who the current master is (alloc index
      # 0 is the master on a cold boot). The conf is copied to a writable
      # /data/redis.conf so Sentinel can CONFIG REWRITE at runtime.
      template {
        destination = "local/redis.conf"
        change_mode = "restart"
        data        = <<-EOF
# Redis Sentinel-Managed Configuration
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
maxmemory-policy noeviction

# Logging
loglevel warning
        EOF
      }

      # --- Startup / Replication Bootstrap ---
      # Deterministic role assignment so a reschedule never produces two
      # standalone masters. Asks any Sentinel who the current master is;
      # alloc index 0 is the cold-boot master, non-zero allocs are always
      # replicas and refuse to self-promote.
      template {
        destination = "local/bootstrap.sh"
        change_mode = "restart"
        data        = <<-EOF
#!/bin/sh
set -eu

CONF=/data/redis.conf
cp /etc/redis/redis.conf.tpl "$CONF"

MY="$${NOMAD_IP_redis}:$${NOMAD_PORT_redis}"

# --- ask any sentinel who the current master is ---
get_master() {
  for s in $${SENTINEL_ADDRS:-}; do
    h=$${s%:*}
    p=$${s##*:}
    out=$(redis-cli -h "$h" -p "$p" sentinel get-master-addr-by-name munchbox-redis 2>/dev/null) || continue
    ip=$(printf '%s\n' "$out" | sed -n 1p)
    port=$(printf '%s\n' "$out" | sed -n 2p)
    if [ -n "$ip" ] && [ -n "$port" ]; then
      printf '%s:%s\n' "$ip" "$port"
      return 0
    fi
  done
  return 1
}

MASTER=""
if [ "$${NOMAD_ALLOC_INDEX}" = "0" ]; then
  # index 0 is the cold-boot master; only step down if sentinel already
  # promoted someone else (i.e. we are restarting after a failover).
  MASTER=$(get_master) || MASTER=""
else
  # non-zero allocs are always replicas; wait for sentinel to name the
  # master rather than ever becoming a second master.
  tries=0
  until MASTER=$(get_master); do
    tries=$((tries + 1))
    if [ "$tries" -ge 150 ]; then
      echo "redis-bootstrap: no master from sentinel after 5m; failing for retry" >&2
      exit 1
    fi
    sleep 2
  done
fi

if [ -n "$MASTER" ] && [ "$MASTER" != "$MY" ]; then
  echo "redis-bootstrap: replica of $MASTER (self $MY, alloc $${NOMAD_ALLOC_INDEX})"
  echo "replicaof $${MASTER%:*} $${MASTER##*:}" >> "$CONF"
else
  echo "redis-bootstrap: master (self $MY, alloc $${NOMAD_ALLOC_INDEX})"
fi

exec redis-server "$CONF"
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
SENTINEL_ADDRS={{ range $i, $s := service "redis-sentinel" }}{{ if ne $i 0 }} {{ end }}{{ $s.Address }}:{{ $s.Port }}{{ end }}
        EOF
      }

      # --- Resources ---
      resources {
        cpu    = 300
        memory = 640
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
        image              = "redis:8.8.0-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        command            = "/bin/sh"
        args               = ["-c", "cp /etc/sentinel/sentinel.conf.tpl /data/sentinel.conf && redis-sentinel /data/sentinel.conf"]

        volumes = [
          "/opt/nomad/data/redis-${NOMAD_ALLOC_INDEX}/sentinel:/data",
          "local/sentinel.conf:/etc/sentinel/sentinel.conf.tpl:ro"
        ]
      }

      # --- Sentinel Configuration ---
      # Bootstrap from any available redis instance — Sentinel discovers
      # the actual master automatically. No ALLOC_INDEX assumptions.
      template {
        destination = "local/sentinel.conf"
        change_mode = "restart"
        data        = <<-EOF
# Sentinel Configuration
port {{ env "NOMAD_PORT_sentinel" }}
dir /data
daemonize no

{{ with secret "secret/data/redis-shared" }}
{{ $password := .Data.data.password }}
# Monitor the current master (redis-primary is healthy only on the master)
{{ range $i, $svc := service "redis-primary" }}
{{ if eq $i 0 }}
sentinel monitor munchbox-redis {{ $svc.Address }} {{ $svc.Port }} 2
sentinel auth-pass munchbox-redis {{ $password }}
{{ end }}
{{ end }}
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
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "oliver006/redis_exporter:v1.86.0"
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
REDIS_EXPORTER_INCL_SYSTEM_METRICS=true
        EOF
      }

      resources {
        cpu    = 200
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

    # --- Eligible nodes for the quorum-only sentinel. Kept to clients with the
    # Consul ACL access it needs for service queries, but as a set rather than a
    # single pin: hard-pinning meant one node being down left two sentinels, and
    # losing a Redis node with its co-located sentinel then left one, which
    # cannot authorise a failover. ---
    constraint {
      attribute = "${node.unique.name}"
      operator  = "set_contains_any"
      value     = "nomad-client-02,nomad-client-03,nomad-client-04"
    }

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
        role        = "nomad-workloads"
        change_mode = "noop"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "redis:8.8.0-alpine"
        image_pull_timeout = "10m"
        network_mode       = "host"
        command            = "/bin/sh"
        args               = ["-c", "echo 'Waiting for redis master...'; while ! grep -q 'sentinel monitor' /etc/sentinel/sentinel.conf.tpl 2>/dev/null || ! grep 'sentinel monitor' /etc/sentinel/sentinel.conf.tpl | grep -qE '[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+'; do sleep 2; done; echo 'Master IP resolved, starting sentinel'; cp /etc/sentinel/sentinel.conf.tpl /tmp/sentinel.conf && redis-sentinel /tmp/sentinel.conf"]

        volumes = [
          "local/sentinel.conf:/etc/sentinel/sentinel.conf.tpl:ro"
        ]
      }

      template {
        destination = "local/sentinel.conf"
        change_mode = "restart"
        data        = <<-EOF
# Sentinel Quorum Configuration (standalone - no local Redis)
#
# Monitors the redis-primary service, which is healthy only on the actual
# master, so the quorum sentinel agrees with the two co-located sentinels.
#
port {{ env "NOMAD_PORT_sentinel" }}
dir /tmp
daemonize no

{{ with secret "secret/data/redis-shared" }}
{{ $password := .Data.data.password }}
# Monitor the current master (redis-primary is healthy only on the master)
{{ range $i, $svc := service "redis-primary" }}
{{ if eq $i 0 }}
sentinel monitor munchbox-redis {{ $svc.Address }} {{ $svc.Port }} 2
sentinel auth-pass munchbox-redis {{ $password }}
{{ end }}
{{ end }}
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
