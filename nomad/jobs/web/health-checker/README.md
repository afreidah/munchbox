# Health Checker

Custom Go service that monitors cron service health on its host node via
D-Bus and exposes the result as an HTTP endpoint. Publicly accessible at
`k3s-status.alexfreidah.com` through the Cloudflare tunnel. Sends traces
to Tempo for observability.

## Notable Configuration

- Unpinned from any specific node; Nomad schedules it on the best
  available node and reschedules automatically on failure
- Mounts the host D-Bus socket for systemd service monitoring

## Dependencies

- **Tempo** -- receives OpenTelemetry traces
