# Blackbox Exporter

Performs synthetic monitoring by probing HTTP, HTTPS, DNS, TCP, and ICMP
endpoints to verify external availability and measure response times.
Scraped by Prometheus for synthetic monitoring metrics.

## Notable Configuration

- Unpinned from any specific node; Nomad schedules it on the best
  available node and reschedules automatically on failure
