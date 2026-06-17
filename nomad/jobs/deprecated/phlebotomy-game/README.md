# phlebotomy-game

Web flashcard game for studying blood-tube order of draw, colors, names, and
contents. Multiple modes (quiz, drag-and-drop, memory matching).

## Image

`registry.munchbox.cc/phlebotomy-game:latest`

## Hostname / exposure

- `study.munchbox.cc`
- HTTPS router via Traefik with `letsencrypt` certresolver
- HTTP router for Cloudflare tunnel (`cf-tunnel-https@file`)
- Both routers gated by `oauth2-proxy@file` forward auth

## Placement

- No node constraint; tiny service (50 MHz / 32 MiB), ephemeral storage

## Dependencies

- Traefik (routing + oauth2-proxy middleware)
- oauth2-proxy (Google SSO)
- No database, no Vault secrets

## Notable configuration

- Tube data templated from `tubes.json` into `/data/tubes.json`
- Container listens on 8080; `/health` for Nomad/Traefik checks
- Static asset image built from this repo, served from the internal registry
