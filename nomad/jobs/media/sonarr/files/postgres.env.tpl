{{ with secret "secret/data/sonarr" }}
SONARR__POSTGRES__USER={{ .Data.data.db_username }}
SONARR__POSTGRES__PASSWORD={{ .Data.data.db_password }}
{{ end }}
