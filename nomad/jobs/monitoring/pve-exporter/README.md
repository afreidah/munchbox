# pve-exporter

Prometheus exporter for the Proxmox VE cluster -- CPU, memory,
storage, temperatures, and per-guest metrics scraped from the Proxmox
API. Targets are wired up in Prometheus, this job just exposes
`/metrics`.

## Image

`prompve/prometheus-pve-exporter:3.5.0`

## Hostname / exposure

- No traefik (`traefik = false`)
- Internal `/metrics` on static port 9221, scraped by Prometheus via
  Consul service discovery

## Placement

- `node = any`, single instance (munchbox-service pack, `size = tiny`)

## Dependencies

- Vault path `secret/data/proxmox` rendered into
  `/etc/pve-exporter/pve.yml` -- holds the `prometheus@pve`
  service-account credentials used to hit the PVE API on every host

## Notable configuration

- Munchbox-service pack job (`.hcl`, not `.nomad.hcl`)
- Args: `--config.file=/etc/pve-exporter/pve.yml`
- Template source: `files/pve.yml.tpl`
- Health check on `/metrics`
