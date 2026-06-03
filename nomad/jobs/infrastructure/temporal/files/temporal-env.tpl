TEMPORAL_BROADCAST_ADDRESS={{ env "NOMAD_IP_http" }}
TEMPORAL_ADDRESS={{ env "NOMAD_IP_http" }}
BIND_ON_IP={{ env "NOMAD_IP_http" }}
{{ with secret "secret/data/temporal" }}
DB=postgres12_pgx
POSTGRES_SEEDS=haproxy-postgres.service.consul
DB_PORT=5433
POSTGRES_USER={{ .Data.data.db_username }}
POSTGRES_PWD={{ .Data.data.db_password }}
SQL_TLS_ENABLED=true
SQL_CA=/secrets/ca.crt
SQL_HOST_VERIFICATION=false
{{ end }}
