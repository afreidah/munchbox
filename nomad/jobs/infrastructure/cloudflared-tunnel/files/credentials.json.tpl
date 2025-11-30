{{ with secret "secret/data/cloudflared" }}{{ .Data.data.credentials_json }}{{ end }}
