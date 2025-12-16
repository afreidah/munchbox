{{ with secret "secret/data/woodpecker" }}
WOODPECKER_AGENT_SECRET={{ .Data.data.agent_secret }}
{{ end }}
