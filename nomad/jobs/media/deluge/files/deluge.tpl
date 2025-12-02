{{ with secret "secret/data/deluge" -}}
DELUGE_LOGLEVEL=info
DELUGE_WEB_LOG_LEVEL=info
{{- end }}
