# Nginx Resume

Static resume website served through NGINX. Handles routing for both the
`resume.alexfreidah.com` subdomain and the `alexfreidah.com` apex domain,
redirecting all variations to the canonical resume URL. Exposed publicly
through the Cloudflare tunnel without OAuth protection.

## Notable Configuration

- Runs three instances across three distinct nodes (`distinct_hosts`
  constraint) for high availability -- this is a public-facing professional
  resume that should tolerate any single node failure without downtime
- Uses bridge networking; Traefik discovers instances via Consul and
  load-balances across all three automatically
