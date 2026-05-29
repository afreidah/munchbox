# Blackbox Exporter (Internal)

Runs on an on-prem nomad client (`meta.cloud != "oracle"`) so probes exercise
direct LAN reachability — pihole web UIs, traefik VIP, anything that resolves
via pihole and isn't meant to ride the WireGuard tunnel.

Scraped by Prometheus (`prometheus.yml.tpl`):
- `blackbox` job: scrapes the exporter's own metrics
- `pihole_probes`: probes `pihole.munchbox.cc`, `pihole-green.munchbox.cc`,
  `pihole-logan.munchbox.cc` via this exporter
