{{ with secret "kv/data/backup-worker" -}}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
{{- end }}
