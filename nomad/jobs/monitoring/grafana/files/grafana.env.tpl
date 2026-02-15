{{ with secret "secret/data/grafana" }}
GF_SECURITY_ADMIN_USER={{ .Data.data.admin_user }}
GF_SECURITY_ADMIN_PASSWORD={{ .Data.data.admin_password }}
GF_DATABASE_TYPE=postgres
GF_DATABASE_HOST=haproxy-postgres.service.consul:5433
GF_DATABASE_NAME=grafana
GF_DATABASE_USER={{ .Data.data.db_username }}
GF_DATABASE_PASSWORD={{ .Data.data.db_password }}
GF_DATABASE_SSL_MODE=require
{{ end }}
