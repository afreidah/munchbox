{{ with secret "secret/data/prowlarr" }}
PROWLARR__POSTGRES__USER={{ .Data.data.db_username }}
PROWLARR__POSTGRES__PASSWORD={{ .Data.data.db_password }}
{{ end }}
