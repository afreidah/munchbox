{{ with secret "secret/data/s3-proxy" }}
server:
  listen_addr: "0.0.0.0:9000"
  virtual_bucket: "unified"

auth:
  access_key_id: "{{ .Data.data.access_key }}"
  secret_access_key: "{{ .Data.data.secret_key }}"
  token: "{{ .Data.data.token }}"

database:
  host: "haproxy-postgres.service.consul"
  port: 5433
  database: "s3proxy"
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
    quota_bytes: 21474836480

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
