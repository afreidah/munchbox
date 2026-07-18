# -------------------------------------------------------------------------------
# Alloy - Unified Telemetry Collection Agent
#
# Project: Munchbox / Author: Alex Freidah
#
# Grafana Alloy replaces Promtail as the log collection agent, providing
# unified log shipping to Loki with trace-to-log correlation via structured
# metadata. Collects systemd journal entries and Nomad allocation logs from
# every client node.
# -------------------------------------------------------------------------------

job "alloy" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "system"
  node_pool   = "all"
  priority    = 50

  # -------------------------------------------------------------------------
  # UPDATE STRATEGY
  # -------------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }

  # -------------------------------------------------------------------------
  # ALLOY GROUP
  # -------------------------------------------------------------------------

  group "alloy" {

    # --- Network configuration ---
    network {
      mode = "host"
      port "http" {
        static = 12345
      }
    }

    # --- Restart policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # --- Service registration ---
    service {
      name     = "alloy"
      port     = "http"
      provider = "consul"

      # --- scrape-path tag points consul-auto at the unix exporter endpoint ---
      # --- scrape-job=node-exporter preserves the historical job label ---
      tags = [
        "traefik.enable=false",
        "logging",
        "alloy",
        "metrics",
        "scrape-path=/api/v0/component/prometheus.exporter.unix.node/metrics",
        "scrape-job=node-exporter",
      ]
      check {
        name      = "alloy-health"
        type      = "http"
        path      = "/-/ready"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # TASK: ALLOY
    # -------------------------------------------------------------------------

    task "alloy" {
      driver = "docker"
      config {
        image              = "grafana/alloy:v1.17.1"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        pid_mode           = "host"
        args = [
          "run",
          "--server.http.listen-addr=0.0.0.0:12345",
          "--storage.path=/var/lib/alloy/data",
          "--disable-reporting",
          "/etc/alloy/config.alloy",
        ]
        volumes = [
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "/var/lib/nomad/alloc:/var/lib/nomad/alloc:ro",
          "/:/host:ro,rslave",
          "local/config.alloy:/etc/alloy/config.alloy:ro",
          "alloy-data:/var/lib/alloy/data",
        ]
      }
      env {
        TZ = "America/Los_Angeles"
      }
      template {
        data        = <<EOH
// -------------------------------------------------------------------------
// LOKI OUTPUT
// -------------------------------------------------------------------------

loki.write "loki" {
  endpoint {
    url = "http://loki.service.consul:3100/loki/api/v1/push"
  }
  external_labels = {
    cluster = "munchbox",
  }
}

// -------------------------------------------------------------------------
// JSON LOG PROCESSING
// -------------------------------------------------------------------------

loki.process "json_logs" {
  forward_to = [loki.write.loki.receiver]

  // Parse JSON log lines (Go slog, Traefik, etc.)
  stage.json {
    expressions = {
      level    = "level",
      msg      = "msg",
      traceID  = "trace_id",
      spanID   = "span_id",
    }
  }

  // Promote level to a label for filtering
  stage.labels {
    values = {
      level = "",
    }
  }

  // Attach trace context as structured metadata for correlation
  stage.structured_metadata {
    values = {
      trace_id = "traceID",
      span_id  = "spanID",
    }
  }
}

// -------------------------------------------------------------------------
// NOMAD ALLOCATION LOGS
// -------------------------------------------------------------------------

// Resolve Nomad alloc log file globs
local.file_match "nomad_stdout" {
  path_targets = [{
    __path__ = "/var/lib/nomad/alloc/*/alloc/logs/*.stdout.[0-9]*",
    job      = "nomad",
    source   = "alloc",
    stream   = "stdout",
  }]
  sync_period = "10s"
}

local.file_match "nomad_stderr" {
  path_targets = [{
    __path__ = "/var/lib/nomad/alloc/*/alloc/logs/*.stderr.[0-9]*",
    job      = "nomad",
    source   = "alloc",
    stream   = "stderr",
  }]
  sync_period = "10s"
}

// Extract task name from Nomad log file paths
loki.relabel "nomad_alloc" {
  forward_to = [loki.process.json_logs.receiver]

  rule {
    source_labels = ["filename"]
    regex         = ".*/([^/]+)\\.(stdout|stderr)\\.[0-9]+"
    target_label  = "task"
    replacement   = "$1"
  }
}

loki.source.file "nomad_stdout" {
  targets    = local.file_match.nomad_stdout.targets
  forward_to = [loki.relabel.nomad_alloc.receiver]
}

loki.source.file "nomad_stderr" {
  targets    = local.file_match.nomad_stderr.targets
  forward_to = [loki.relabel.nomad_alloc.receiver]
}

// -------------------------------------------------------------------------
// SYSTEMD JOURNAL LOGS
// -------------------------------------------------------------------------

// Map journal fields to useful labels
loki.relabel "journal" {
  forward_to = []

  rule {
    source_labels = ["__journal__systemd_unit"]
    target_label  = "unit"
  }

  rule {
    source_labels = ["__journal__hostname"]
    target_label  = "node"
  }

  rule {
    source_labels = ["__journal__syslog_identifier"]
    target_label  = "service"
  }

  rule {
    source_labels = ["__journal_priority_keyword"]
    target_label  = "level"
  }
}

loki.source.journal "systemd" {
  forward_to    = [loki.write.loki.receiver]
  relabel_rules = loki.relabel.journal.rules
  max_age       = "12h"
  labels        = {
    job    = "systemd",
    source = "journal",
  }
}

// -------------------------------------------------------------------------
// NODE METRICS
// -------------------------------------------------------------------------
// Endpoint: :12345/api/v0/component/prometheus.exporter.unix.node/metrics
// Both prom replicas scrape it via consul-auto (scrape-path tag on alloy).

prometheus.exporter.unix "node" {
  rootfs_path = "/host"
  procfs_path = "/host/proc"
  sysfs_path  = "/host/sys"

  enable_collectors  = ["processes", "hwmon", "thermal_zone"]
  disable_collectors = ["wifi"]

  filesystem {
    fs_types_exclude     = "^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|fuse\\.sshfs|tmpfs)$"
    mount_points_exclude = "^/(dev|proc|sys|var/lib/docker/.+|run/.+|mnt/gdrive)($|/)"
  }
}

EOH
        destination = "local/config.alloy"
        change_mode = "restart"
      }

      # --- Resources ---
      resources {
        cpu    = 500
        memory = 256
      }

      # --- Termination ---
      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
