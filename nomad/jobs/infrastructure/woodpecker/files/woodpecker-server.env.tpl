{{ with secret "secret/data/woodpecker" }}
WOODPECKER_FORGEJO_CLIENT={{ .Data.data.forgejo_client_id }}
WOODPECKER_FORGEJO_SECRET={{ .Data.data.forgejo_client_secret }}
WOODPECKER_AGENT_SECRET={{ .Data.data.agent_secret }}
WOODPECKER_DATABASE_DATASOURCE=postgres://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@postgres-shared.service.consul:5432/woodpecker?sslmode=disable
{{ end }}
