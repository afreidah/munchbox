{{ with secret "secret/data/s3-orchestrator" }}
server:
  listen_addr: "0.0.0.0:9000"
  backend_timeout: "5m"

buckets:
  - name: "unified"
    credentials:
      - access_key_id: "{{ .Data.data.access_key }}"
        secret_access_key: "{{ .Data.data.secret_key }}"

database:
  host: "haproxy-postgres.service.consul"
  port: 5433
  database: "s3_orchestrator"
  user: "{{ .Data.data.db_username }}"
  password: "{{ .Data.data.db_password }}"
  ssl_mode: "require"

backends:
  - name: "oci"
    endpoint: "{{ .Data.data.oci_s3_endpoint }}"
    region: "{{ .Data.data.oci_s3_region }}"
    bucket: "{{ .Data.data.oci_s3_bucket }}"
    access_key_id: "{{ .Data.data.oci_s3_access_key }}"
    secret_access_key: "{{ .Data.data.oci_s3_secret_key }}"
    force_path_style: true
    quota_bytes: 10737418240

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
