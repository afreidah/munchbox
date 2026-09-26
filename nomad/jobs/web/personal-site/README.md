# personal-site

Personal site served at the `alexfreidah.com` apex: home page, resume
(`/resume/`), and posts. Built from
[afreidah/personal-site](https://github.com/afreidah/personal-site).

## Image

`registry.munchbox.cc/personal-site:v0.1.1`

## Hostname / exposure

- `alexfreidah.com`, reached publicly via the Cloudflare tunnel
- Router `alex-web` on the `web` entrypoint, priority 101 (one above
  the docs sites), with `resume-sec@file` and `resume-ratelimit@file`
- `www.alexfreidah.com` redirects (301) to the apex
- `resume.alexfreidah.com` and `www.resume.alexfreidah.com` redirect
  (301) to `https://alexfreidah.com/resume/` through router
  `alex-resume`
- Both redirect middlewares are defined in the job's service tags

## Placement

- `node = any`, `count = 4` with `distinct_hosts = true`
- Munchbox-service pack job, `size = tiny`

## Dependencies

- None -- static site

## Notable configuration

- Container port 80, ephemeral storage
- 50 MHz / 32 MiB per alloc
- Healthcheck on `/`
