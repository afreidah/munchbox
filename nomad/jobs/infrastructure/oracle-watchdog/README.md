# Oracle Watchdog

Monitors Oracle Cloud free-tier nodes via Consul session presence and
triggers OCI stop/start cycles when nodes become unresponsive. Oracle's
free-tier instances occasionally hang or lose network connectivity, and
this agent automates recovery without manual intervention.

## Architecture

The agent polls Consul for heartbeat keys from each monitored Oracle
node. When a node's session is missing for longer than the configured
timeout (5 minutes), the agent calls the OCI API to stop and restart
the instance. A restart attempt counter (max 3) prevents infinite loops
on hardware failures; the counter resets when a node recovers.

## Notable Configuration

- Constrained to run on non-Oracle nodes to avoid the watchdog dying
  alongside the nodes it monitors
- Exposes Prometheus metrics on port 9105 for alerting on recovery events
- OCI credentials (API key, config) injected from Vault

## Dependencies

- **Consul** -- session monitoring for node liveness detection
