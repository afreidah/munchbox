{{ with secret "kv/data/deluge" -}}
DELUGE_WEB_PASSWORD={{ .Data.data.web_password }}
{{- end }}
