{{ with secret "secret/data/prometheus-nomad" }}
{{ .Data.data.nomad_token }}
{{ end }}
