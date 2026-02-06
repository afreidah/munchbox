{{ with secret "secret/data/temporal" }}
DB=postgres12_pgx
POSTGRES_SEEDS=postgres-primary.service.consul
POSTGRES_USER={{ .Data.data.db_username }}
POSTGRES_PWD={{ .Data.data.db_password }}
SQL_TLS_ENABLED=true
SQL_CA=/secrets/ca.crt
SQL_HOST_VERIFICATION=false
{{ end }}
