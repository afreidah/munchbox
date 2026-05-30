# flight-fetcher

Polls OpenSky and a local dump1090 receiver for aircraft within ~200
km of home, enriches via AirLabs / FlightAware / HexDB, stores
current state in Redis and history in PostgreSQL, and serves a small
dashboard plus a squawk monitor.

## Image

`registry.munchbox.cc/flight-fetcher:v0.9.25`

## Hostname / exposure

- `flights.munchbox.cc`
- HTTPS through `oauth2-proxy-errors@file,oauth2-proxy@file`
- HTTP variant adds `cf-tunnel-https@file`

## Placement

- `node_pool = default`, single instance
- Host network, static port 8080

## Dependencies

- PostgreSQL `flight_fetcher` database via
  `haproxy-postgres.service.consul:5433` (sslmode require,
  `target_session_attrs=read-write` to land on the primary)
- Redis at `redis.service.consul:6379` (password from Vault)
- Vault path `secret/data/flight-fetcher` with OpenSky id/secret,
  AirLabs key, FlightAware key, Redis password, db creds
- Vault role `flight-fetcher`
- Tempo at `tempo.service.consul:4317`
- External: OpenSky API, AirLabs, FlightAware, dump1090 at
  `192.168.68.79`

## Notable configuration

- Center: 34.0928, -118.3287, radius 200 km
- OpenSky poll 240s, dump1090 poll 5s
- Enrichment cache refresh 5h; sightings retained 720h, alerts 168h,
  routes 24h
- `GOMAXPROCS=1`, `GOMEMLIMIT=96MiB` with `memory_max=256`
