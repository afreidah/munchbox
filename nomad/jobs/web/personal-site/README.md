# personal-site

Personal landing page served at the `alexfreidah.com` apex (and
`www.`). Replaces the previous apex redirect to
`resume.alexfreidah.com`; the resume itself still lives behind the
separate nginx-resume job.

## Image

`registry.munchbox.cc/personal-site:v0.0.5`

## Hostname / exposure

- `alexfreidah.com` and `www.alexfreidah.com`
- Traefik router on the `web` entrypoint, reached publicly via the
  Cloudflare tunnel
- Middleware `resume-sec@file` for security headers
- Router priority 101 (one above the docs sites)

## Placement

- `node = any`, `count = 3` with `distinct_hosts = true`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
