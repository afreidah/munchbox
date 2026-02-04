# Cloudflared Tunnel

Runs the Cloudflare tunnel connector that provides external access to
cluster services without exposing ports to the public internet. This job
only runs the tunnel process itself -- ingress routing rules are managed
by Terraform in `infrastructure/terraform/dns/main.tf` via the
`cloudflare_tunnel_config` resource.

## Architecture

The connector authenticates with a token stored in Vault that includes
the tunnel ID and credentials. Cloudflare's edge network routes incoming
requests through this tunnel to Traefik's HTTP entrypoint, where services
are reached via their standard Traefik routing rules. The tunnel token is
the only secret; ingress configuration is fetched from the Cloudflare API
at runtime.

## Notable Configuration

- Pinned to goren (primary ingress node) for stable external connectivity
- Metrics exposed on port 2000 for health monitoring
- Tunnel routing changes require a Terraform apply, not a job redeploy

## Dependencies

- **Traefik** -- all tunneled traffic enters through the HTTP entrypoint
- **Vault** -- tunnel token credential storage
