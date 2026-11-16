modules:
  https_2xx:
    prober: http
    http:
      method: GET
      fail_if_not_ssl: true
      preferred_ip_protocol: "ip4"
      valid_http_versions: ["HTTP/1.1","HTTP/2.0"]
      # --- Cloudflare's WAF skips its bot challenges for requests carrying
      #     this token. From an Oracle node the probe is classed as automated
      #     and challenged, so without it every Cloudflare-fronted probe reads
      #     403 instead of the site. ---
      headers:
        X-Munchbox-Probe: '{{ with secret "secret/data/blackbox-exporter-external" }}{{ .Data.data.probe_token }}{{ end }}'
      tls_config:
        insecure_skip_verify: false

  # Plain-HTTP probe for sites that are public via Cloudflare tunnel but
  # only listen on HTTP internally (so probing the HTTPS URL from inside
  # the cluster hits Traefik with no matching :443 router and 404s).
  http_2xx:
    prober: http
    http:
      method: GET
      fail_if_ssl: true
      preferred_ip_protocol: "ip4"
      valid_http_versions: ["HTTP/1.1","HTTP/2.0"]

