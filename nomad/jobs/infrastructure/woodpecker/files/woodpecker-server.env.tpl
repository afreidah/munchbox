{{ with secret "secret/data/woodpecker" }}
WOODPECKER_GITHUB_CLIENT={{ .Data.data.github_client_id }}
WOODPECKER_GITHUB_SECRET={{ .Data.data.github_client_secret }}
WOODPECKER_AGENT_SECRET={{ .Data.data.agent_secret }}
WOODPECKER_DATABASE_DATASOURCE=postgres://{{ .Data.data.db_username }}:{{ .Data.data.db_password }}@postgres-shared.service.consul:5432/woodpecker?sslmode=disable
{{ end }}
