{{ with secret "secret/data/deluge" }}
localclient:{{ .Data.data.password }}:10
{{ end }}
