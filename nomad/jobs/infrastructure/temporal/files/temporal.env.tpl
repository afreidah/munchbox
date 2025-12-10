{{ with secret "secret/data/temporal" }}
POSTGRES_USER={{ .Data.data.db_username }}
POSTGRES_PWD={{ .Data.data.db_password }}
{{ end }}
