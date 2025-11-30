{{ with secret "secret/data/backup-tokens" -}}
NOMAD_TOKEN={{ .Data.data.nomad_token }}
CONSUL_HTTP_TOKEN={{ .Data.data.consul_token }}
BAO_TOKEN={{ .Data.data.bao_token }}
{{- end }}
