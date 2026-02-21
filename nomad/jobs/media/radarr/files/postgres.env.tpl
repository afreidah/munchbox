{{ with secret "secret/data/radarr" }}
RADARR__POSTGRES__USER={{ .Data.data.db_username }}
RADARR__POSTGRES__PASSWORD={{ .Data.data.db_password }}
{{ end }}
