{{ with secret "secret/data/readarr" }}
READARR__POSTGRES__USER={{ .Data.data.db_username }}
READARR__POSTGRES__PASSWORD={{ .Data.data.db_password }}
{{ end }}
