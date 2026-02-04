# CoreDNS

DNS load balancer that distributes queries across both Pi-hole servers.
Runs as a system job so every node has a local DNS forwarder on port 5353,
which each node's dnsmasq uses for non-Consul query resolution.

## Architecture

CoreDNS forwards all queries to both Pi-holes using round-robin with
health checks. If one Pi-hole goes down, CoreDNS automatically routes
all queries to the healthy instance. A local cache (5 minutes for
positive, 1 minute for negative responses) reduces upstream load.

## Notable Configuration

- System job type ensures every cluster node gets local DNS automatically
- Sends traces to Tempo via the Zipkin endpoint for DNS query observability
- Prometheus metrics on port 9153 for query rate and latency monitoring
- Priority 80 ensures DNS is available before most services start

## Dependencies

- **Pi-hole (green, logan)** -- upstream DNS servers
- **Tempo** -- receives Zipkin traces
- **Prometheus** -- scrapes DNS metrics
