TEMPORAL_BROADCAST_ADDRESS={{ env "NOMAD_IP_http" }}
TEMPORAL_ADDRESS={{ env "NOMAD_IP_http" }}
BIND_ON_IP={{ env "NOMAD_IP_http" }}
{{ $leader := key "service/munchbox-postgres/leader" }}
{{ $member := key (printf "service/munchbox-postgres/members/%s" $leader) | parseJSON }}
{{ with secret "secret/data/temporal" }}
DB=postgres12_pgx
POSTGRES_SEEDS={{ $member.conn_url | regexReplaceAll "^postgres://" "" | regexReplaceAll ":.*" "" }}
POSTGRES_PORT=5433
POSTGRES_USER={{ .Data.data.db_username }}
POSTGRES_PWD={{ .Data.data.db_password }}
SQL_TLS_ENABLED=true
SQL_CA=/secrets/ca.crt
SQL_HOST_VERIFICATION=false
{{ end }}
