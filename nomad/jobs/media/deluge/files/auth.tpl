{{ with secret "kv/data/deluge" }}
localclient:{{ .Data.data.password }}:10
{{ end }}
