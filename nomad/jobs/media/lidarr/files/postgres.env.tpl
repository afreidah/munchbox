{{ with secret "secret/data/lidarr" }}
LIDARR__POSTGRES__USER={{ .Data.data.db_username }}
LIDARR__POSTGRES__PASSWORD={{ .Data.data.db_password }}
{{ end }}
