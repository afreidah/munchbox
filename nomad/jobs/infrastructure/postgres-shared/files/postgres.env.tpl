{{ with secret "secret/data/postgres-shared/root" }}
POSTGRES_USER={{ .Data.data.username }}
POSTGRES_PASSWORD={{ .Data.data.password }}
{{ end }}
