# oracle-watchdog

Monitors Oracle Cloud free-tier nodes via Consul session presence and triggers
OCI stop/start cycles when nodes become unresponsive. Also publishes the home
WAN IP to Cloudflare DNS so the WireGuard endpoint stays reachable when the
residential IP changes.

## Image

`registry.munchbox.cc/oracle-watchdog:v1.4.1`

## Hostname / exposure

- Internal-only Consul service `oracle-watchdog-agent`
- Prometheus metrics on static port 9105 (`traefik.enable=false`)

## Placement

- Constraints: `meta.cloud != oracle` (so the watchdog can't die with its
  target nodes), `attr.cpu.arch = amd64` (image is x86_64),
  `node.unique.name != nomad-client-04` (keep off the GPU node)
- `count = 1`

## Dependencies

- Consul at `consul.service.consul:8500` for session monitoring
- Vault `secret/data/oracle-watchdog` (OCI private key) and
  `secret/data/cloudflare-wandns` (zone_id + api_token) via the `oracle-watchdog` role
- Tempo OTLP `tempo.service.consul:4317` (tracing)

## Notable configuration

- Watched nodes: `oraclearm1`, `oraclearm2`, `oraclenode1`, `oraclenode2`
- `timeout: 300s` (node missing 5m before restart), `check_interval: 60s`
- `max_restart_attempts: 0` -- unlimited; counter resets on recovery
- `wan_dns` keeps `wg.munchbox.cc` A record in sync with WAN IP via
  Cloudflare API; `poll_interval: 5m`, `cooldown: 15m`
- OCI config block (user/tenancy/fingerprint/region us-phoenix-1) baked into
  the rendered config; private key from Vault
