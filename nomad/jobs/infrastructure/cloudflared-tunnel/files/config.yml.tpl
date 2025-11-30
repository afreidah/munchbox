tunnel: {{ with secret "secret/data/cloudflared" }}{{ .Data.data.tunnel_uuid }}{{ end }}
credentials-file: /local/credentials.json

# Enable metrics and health endpoints
metrics: 0.0.0.0:2000

ingress:
  - hostname: "alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: alexfreidah.com
  
  - hostname: "www.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: www.alexfreidah.com
  
  - hostname: "resume.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: resume.alexfreidah.com
  
  - hostname: "k3s-status.alexfreidah.com"
    service: "http://traefik.service.consul:80"
    originRequest:
      httpHostHeader: k3s-status.alexfreidah.com
  
  - service: http_status:404

warp-routing:
  enabled: false
