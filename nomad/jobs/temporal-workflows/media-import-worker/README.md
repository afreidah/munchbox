# media-import-worker

Temporal worker that reconciles completed Deluge downloads grabbed outside
Sonarr/Radarr into the media library so Jellyfin can see them. It lists the
100%-complete torrents, force-imports the genuinely-missing episodes/movies
via the Sonarr/Radarr manual-import API (hardlink, keep seeding), then triggers
a Jellyfin scan. Listens on the `media-import-task-queue`; the `Reconcile`
workflow is started on schedule by a Temporal Schedule.

## Image

`registry.munchbox.cc/media-import-worker:latest`

## Hostname / exposure

- No traefik
- Metrics on a dynamic host port (`METRICS_LISTEN`), scraped via Consul

## Placement

- Off the Oracle cloud nodes (`meta.cloud != oracle`) -- needs LAN access to
  the media services

## Dependencies

- Temporal at `temporal-server.service.consul:7233`
- Vault via Workload Identity (`nomad-workloads` role); reads Sonarr/Radarr keys
  from `secret/media-import`, Deluge `web_password` from `secret/deluge`, and
  the Jellyfin `api_key` from `secret/jellyfin`
- Sonarr `sonarr.service.consul:8989`, Radarr `radarr.service.consul:7878`,
  Deluge `deluge.service.consul:8112`, Jellyfin `jellyfin.service.consul:8096`
- Tempo at `tempo.service.consul:4317`

## Notable configuration

- Host network
- 200 MHz / 256 MiB -- light; bounded HTTP calls, no local unpacking
- No static secrets templated into the job; the worker pulls every credential
  through its own Vault client (WI token at `/secrets/vault_token`)
