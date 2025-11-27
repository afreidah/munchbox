{{ with secret "secret/data/prometheus" }}
{{ .Data.data.consul_token }}
{{ end }}
