# -------------------------------------------------------------------------------
# s3-orchestrator — Munchbox Deployment
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job "s3-orchestrator" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "service"
  node_pool   = "default"
  priority    = 50

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------


  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------
  update {
    max_parallel      = 1
    canary            = 0
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  # Task Group: s3-orchestrator
  # ---------------------------------------------------------------------------

  group "s3-orchestrator" {
    count = 1

    # --- Network Configuration ---
    network {
      mode = "host"
      port "http" {
        static = 9000
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
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    # --- Service Registration ---
    service {
      name     = "s3-orchestrator"
      port     = "http"
      provider = "consul"

      tags = [
        "metrics",
        "traefik.enable=true",
        "traefik.http.routers.s3-orchestrator.rule=Host(`s3.munchbox.cc`)",
        "traefik.http.routers.s3-orchestrator.entrypoints=websecure",
        "traefik.http.routers.s3-orchestrator.tls=true",
        "traefik.http.services.s3-orchestrator.loadbalancer.server.port=9000",
        "infrastructure",
        "s3-orchestrator",
        "storage",
        "traefik.http.routers.s3-orchestrator.middlewares=oauth2-proxy-errors@file,oauth2-proxy@file",
        "traefik.http.routers.s3-orchestrator-http.rule=Host(`s3.munchbox.cc`)",
        "traefik.http.routers.s3-orchestrator-http.entrypoints=web",
        "traefik.http.routers.s3-orchestrator-http.middlewares=cf-tunnel-https@file,oauth2-proxy-errors@file,oauth2-proxy@file",
      ]
      check {
        name      = "s3-orchestrator-health"
        type      = "http"
        path      = "/health"
        port      = "http"
        interval  = "10s"
        timeout   = "3s"
        on_update = "require_healthy"
      }
    }

    # -------------------------------------------------------------------------
    # Task: s3-orchestrator
    # -------------------------------------------------------------------------

    task "s3-orchestrator" {
      driver = "docker"
      vault {
        role = "s3-orchestrator"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }
      config {
        image              = "registry.munchbox.cc/s3-orchestrator:v0.61.1"
        image_pull_timeout = "10m"
        ports              = ["http"]
        network_mode       = "host"
        args               = ["-config", "/secrets/config.yaml"]
        volumes            = ["secrets/config.yaml:/secrets/config.yaml:ro", "secrets/vault-ca.pem:/secrets/vault-ca.pem:ro"]
      }
      env {
        TZ         = "America/Los_Angeles"
        GOMAXPROCS = "1"
        GOMEMLIMIT = "200MiB"
      }
      template {
        data        = <<EOH
{{ with secret "secret/data/s3-orchestrator" }}
server:
  listen_addr: "0.0.0.0:9000"
  backend_timeout: "15m"
  write_timeout: "20m"
  read_timeout: "20m"
  shutdown_delay: "5s"

routing_strategy: "spread"

buckets:
  - name: "unified"
    credentials:
      - access_key_id: "{{ with secret "secret/data/s3-bucket/unified" }}{{ .Data.data.access_key }}{{ end }}"
        secret_access_key: "{{ with secret "secret/data/s3-bucket/unified" }}{{ .Data.data.secret_key }}{{ end }}"
  - name: "aptly"
    credentials:
      - access_key_id: "{{ with secret "secret/data/s3-bucket/aptly" }}{{ .Data.data.access_key }}{{ end }}"
        secret_access_key: "{{ with secret "secret/data/s3-bucket/aptly" }}{{ .Data.data.secret_key }}{{ end }}"

database:
  host: "haproxy-postgres.service.consul"
  port: 5433
  database: "s3_orchestrator"
  user: "{{ .Data.data.db_username }}"
  password: "{{ .Data.data.db_password }}"
  ssl_mode: "require"
  max_conns: 10
  min_conns: 5
  max_conn_lifetime: "5m"

backends:
  - name: "oci"
    endpoint: "{{ .Data.data.oci_s3_endpoint }}"
    region: "{{ .Data.data.oci_s3_region }}"
    bucket: "{{ .Data.data.oci_s3_bucket }}"
    access_key_id: "{{ .Data.data.oci_s3_access_key }}"
    secret_access_key: "{{ .Data.data.oci_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 10737418240
    api_request_limit: 50000
    egress_byte_limit: 10737418240
  - name: "r2"
    endpoint: "{{ .Data.data.r2_s3_endpoint }}"
    region: "auto"
    bucket: "{{ .Data.data.r2_s3_bucket }}"
    access_key_id: "{{ .Data.data.r2_s3_access_key }}"
    secret_access_key: "{{ .Data.data.r2_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 10737418240
    api_request_limit: 1000000
  - name: "e2"
    endpoint: "{{ .Data.data.e2_s3_endpoint }}"
    region: "{{ .Data.data.e2_s3_region }}"
    bucket: "{{ .Data.data.e2_s3_bucket }}"
    access_key_id: "{{ .Data.data.e2_s3_access_key }}"
    secret_access_key: "{{ .Data.data.e2_s3_secret_key }}"
    force_path_style: true
    disable_checksum: true
    quota_bytes: 10737418240
    egress_byte_limit: 10737418240
    ingress_byte_limit: 10737418240
  - name: "ibm"
    endpoint: "{{ .Data.data.ibm_s3_endpoint }}"
    region: "{{ .Data.data.ibm_s3_region }}"
    bucket: "{{ .Data.data.ibm_s3_bucket }}"
    access_key_id: "{{ .Data.data.ibm_s3_access_key }}"
    secret_access_key: "{{ .Data.data.ibm_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 5368709120
    egress_byte_limit: 5368709120
    ingress_byte_limit: 5368709120
  - name: "gcp"
    endpoint: "{{ .Data.data.gcp_s3_endpoint }}"
    region: "{{ .Data.data.gcp_s3_region }}"
    bucket: "{{ .Data.data.gcp_s3_bucket }}"
    access_key_id: "{{ .Data.data.gcp_s3_access_key }}"
    secret_access_key: "{{ .Data.data.gcp_s3_secret_key }}"
    force_path_style: true
    disable_checksum: true
    unsigned_payload: true
    strip_sdk_headers: true
    quota_bytes: 5368709120
    egress_byte_limit: 1073741824
    ingress_byte_limit: 5368709120
    api_request_limit: 5000
  - name: "b2"
    endpoint: "{{ .Data.data.b2_s3_endpoint }}"
    region: "{{ .Data.data.b2_s3_region }}"
    bucket: "{{ .Data.data.b2_s3_bucket }}"
    access_key_id: "{{ .Data.data.b2_s3_access_key }}"
    secret_access_key: "{{ .Data.data.b2_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 10737418240       # 10 GB storage
    egress_byte_limit: 32212254720 # 30 GB/month egress (1 GB/day × 30)
    api_request_limit: 75000       # 2,500/day × 30 Class B/C
  - name: "g3"
    endpoint: "{{ .Data.data.g3_s3_endpoint }}"
    region: "us-east-1"
    bucket: "{{ .Data.data.g3_s3_bucket }}"
    unsigned_payload: true
    access_key_id: "{{ .Data.data.g3_s3_access_key }}"
    secret_access_key: "{{ .Data.data.g3_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 16106127360      # 15 GB
  - name: "supabase"
    endpoint: "{{ .Data.data.supabase_s3_endpoint }}"
    region: "{{ .Data.data.supabase_s3_region }}"
    bucket: "{{ .Data.data.supabase_s3_bucket }}"
    access_key_id: "{{ .Data.data.supabase_s3_access_key }}"
    secret_access_key: "{{ .Data.data.supabase_s3_secret_key }}"
    force_path_style: true
    disable_checksum: true
    quota_bytes: 1073741824        # 1 GB storage
    max_object_size: 52428800      # 50 MB per-object limit
    egress_byte_limit: 5368709120  # 5 GB/month egress
  - name: "c2"
    endpoint: "{{ .Data.data.c2_s3_endpoint }}"
    region: "us-east-1"
    bucket: "{{ .Data.data.c2_s3_bucket }}"
    access_key_id: "{{ .Data.data.c2_s3_access_key }}"
    secret_access_key: "{{ .Data.data.c2_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 16106127360       # 15 GB storage
    egress_byte_limit: 16106127360 # 15 GB/month egress
  - name: "tigris"
    endpoint: "{{ .Data.data.tigris_s3_endpoint }}"
    region: "{{ .Data.data.tigris_s3_region }}"
    bucket: "{{ .Data.data.tigris_s3_bucket }}"
    access_key_id: "{{ .Data.data.tigris_s3_access_key }}"
    secret_access_key: "{{ .Data.data.tigris_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 5368709120        # 5 GB storage
    api_request_limit: 110000      # 10K Class A + 100K Class B/month
  - name: "minio"
    endpoint: "{{ .Data.data.minio_s3_endpoint }}"
    region: "us-east-1"
    bucket: "{{ .Data.data.minio_s3_bucket }}"
    access_key_id: "{{ .Data.data.minio_s3_access_key }}"
    secret_access_key: "{{ .Data.data.minio_s3_secret_key }}"
    force_path_style: true
    unsigned_payload: true
    quota_bytes: 75161927680       # 70 GiB (75 GB avail on 80 GB volume, ~5 GB headroom)
  - name: "minio-arm2"
    endpoint: "{{ .Data.data.minio_arm2_s3_endpoint }}"
    region: "us-east-1"
    bucket: "{{ .Data.data.minio_arm2_s3_bucket }}"
    access_key_id: "{{ .Data.data.minio_arm2_s3_access_key }}"
    secret_access_key: "{{ .Data.data.minio_arm2_s3_secret_key }}"
    force_path_style: true
    unsigned_payload: true
    quota_bytes: 75161927680       # 70 GiB


circuit_breaker:
  failure_threshold: 3
  open_timeout: 1200s
  cache_ttl: 120s
  parallel_broadcast: true
  degraded_broadcast_parallelism: 4

backend_circuit_breaker:
  enabled: true
  failure_threshold: 3
  open_timeout: 30m

write_path:
  pending_pattern:
    reaper_tick: 10m
    min_age: 15m
    batch_size: 10

integrity:
  enabled: true
  verify_on_read: false
  scrubber_interval: "24h"
  scrubber_batch_size: 10

encryption:
  enabled: true
  vault:
    address: "https://vault.service.consul:8200"
    token_file: "/secrets/vault_token"
    key_name: "s3-orchestrator"
    mount_path: "transit"
    ca_cert: "/secrets/vault-ca.pem"

rate_limit:
  enabled: true
  requests_per_sec: 1500
  burst: 2000
  trusted_proxies:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
    - "127.0.0.1/32"

admin:
  token: "{{ .Data.data.admin_token }}"

cache:
  enabled: true
  max_size: "32MB"
  max_object_size: "5MB"
  ttl: "15m"

reconcile:
  enabled: true
  interval: "24h"

cleanup_queue:
  concurrency: 4
  multipart_stale_timeout: "24h"
  claim_grace_period: "10m"

rebalance:
  enabled: true
  strategy: "spread"
  interval: "24h"
  batch_size: 100
  threshold: 0.1
  concurrency: 2

replication:
  factor: 2
  batch_size: 20
  worker_interval: "2m"

ui:
  enabled: true
  admin_key: "{{ .Data.data.ui_admin_key }}"
  admin_secret: "{{ .Data.data.ui_admin_secret }}"
  session_secret: "{{ .Data.data.session_secret }}"
  force_secure_cookies: true

usage_flush:
  interval: "30s"
  adaptive_enabled: true
  adaptive_threshold: 0.8
  fast_interval: "5s"

telemetry:
  metrics:
    enabled: true
    path: "/metrics"
  tracing:
    enabled: true
    endpoint: "tempo.service.consul:4317"
    insecure: true
    sample_rate: 1.0
{{ end }}

EOH
        destination = "secrets/config.yaml"
        change_mode = "restart"
      }
      template {
        data        = <<EOH
{{ with secret "pki_int/cert/ca" }}{{ .Data.certificate }}{{ end }}

EOH
        destination = "secrets/vault-ca.pem"
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
  meta = {
    managed_by             = "nomad-pack"
    "pack.deployment_name" = "munchbox-service"
    "pack.job"             = "s3-orchestrator"
    "pack.name"            = "munchbox-service"
    "pack.path"            = "/home/afreidah/tools/munchbox/nomad/packs/registry/munchbox-service"
    "pack.registry"        = "<<local folder>>"
    "pack.version"         = "<<none>>"
    project                = "munchbox"
  }
}
