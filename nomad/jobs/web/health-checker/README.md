# Health Checker

Custom Go service that monitors cron service health on its host node via
D-Bus and exposes the result as an HTTP endpoint. Publicly accessible at
`k3s-status.alexfreidah.com` through the Cloudflare tunnel. Sends traces
to Tempo for observability.

## Dependencies

- **Tempo** -- receives OpenTelemetry traces
