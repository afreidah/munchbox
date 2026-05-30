# nginx-resume

Static nginx site serving the resume at `resume.alexfreidah.com`. The apex
`alexfreidah.com` is NOT handled here -- that lives in the `personal-site` job.

## image

`registry.munchbox.cc/alex-resume:v0.0.1`

## hostname / exposure

- `resume.alexfreidah.com` and `www.resume.alexfreidah.com`
- Traefik router `resume-public` on the `web` entrypoint only (Cloudflare
  tunnel fronts TLS); priority `100`
- middlewares: `redirect-resume-www@file,resume-sec@file,resume-ratelimit@file`

## placement

- `node = any`, `count = 3`, `distinct_hosts = true`
- one instance per node for redundancy behind Traefik / cloudflared
- size `tiny` (50 MHz CPU, 32 MiB memory), ephemeral storage

## dependencies

- none -- pure static content baked into the image
- fronted by Traefik, which is fronted by cloudflared

## notable configuration

- `vault = false`; no secrets needed
- health check path `/`
- image is built and pushed to the in-house registry; bumping the resume
  means a new image tag and a redeploy
