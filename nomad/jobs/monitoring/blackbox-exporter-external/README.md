# Blackbox Exporter (External)

Runs on an oracle cloud node so probes exercise outside-in reachability for
public services (Cloudflare tunnel + dual-ingress). Pairs with
`blackbox-exporter-internal/`, which handles LAN-only / internal-DNS targets.

Scraped by Prometheus (`prometheus.yml.tpl`):
- `blackbox` job: scrapes the exporter's own metrics
- `site_https` / `site_http`: synthetic probes of public sites via this exporter
