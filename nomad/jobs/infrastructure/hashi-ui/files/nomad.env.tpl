{{ with secret "secret/data/hashiuisecret" }}
NOMAD_ACL_TOKEN={{ .Data.data.token }}
{{ end }}
