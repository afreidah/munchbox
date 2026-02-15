# Cloudflared Tunnel

Runs the Cloudflare tunnel connector that provides external access to
cluster services without exposing ports to the public internet. This job
only runs the tunnel process itself -- ingress routing rules are managed
by Terraform in `infrastructure/terraform/dns/main.tf` via the
`cloudflare_tunnel_config` resource.

## Architecture

Runs as a system job on both ingress nodes. Cloudflare natively supports
multiple connectors per tunnel, distributing traffic across them and
failing over automatically if one connector goes down. Each instance
forwards incoming requests to the local Traefik HTTP entrypoint.

The connector authenticates with a token stored in Vault that includes
the tunnel ID and credentials. Cloudflare's edge network routes incoming
requests through the tunnel to Traefik, where services are reached via
their standard Traefik routing rules. The tunnel token is the only
secret; ingress configuration is fetched from the Cloudflare API at
runtime.

## Notable Configuration

- System job constrained to `meta.role = "ingress"` nodes
- Metrics exposed on port 2000 for health monitoring
- Tunnel routing changes require a Terraform apply, not a job redeploy

## Dependencies

- **Traefik** -- all tunneled traffic enters through the HTTP entrypoint
- **Vault** -- tunnel token credential storage
