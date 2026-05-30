# vault-ui

Tiny nginx that 302-redirects `vault-ui.munchbox.cc` -> the built-in
Vault UI at `https://vault.munchbox.cc:8200/ui`. The old
`djenriquez/vault-ui` had critical vulns and is unmaintained; Vault's
own UI is fine, this job just gives it a clean URL behind oauth2-proxy.

## Image

`nginx:alpine`

## Hostname / exposure

- `vault-ui.munchbox.cc`
- HTTPS router on `websecure`, gated by `oauth2-proxy@file`
- HTTP router on `web` for Cloudflare tunnel (same auth chain)
- nginx listens on static host port 8280

## Placement

- `node_pool = oracle` + constraint
  `node.unique.name set_contains_any oraclenode1,oraclenode2`
- Trivial workload kept on Oracle so it doesn't burn home-lab capacity

## Dependencies

- oauth2-proxy (forward auth)
- The actual Vault server at `vault.munchbox.cc:8200` (the redirect target)

## Notable configuration

- nginx config: 200 on `/health`, 302 on `/` to
  `https://vault.munchbox.cc:8200/ui$request_uri`
- 50 MHz / 32 MiB; host networking
