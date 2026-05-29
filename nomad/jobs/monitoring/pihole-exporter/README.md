# Pi-hole Exporter

Single `ekofr/pihole-exporter` instance scraping both pihole nodes (green +
logan) via comma-separated `PIHOLE_HOSTNAME`. Replaces the on-Pi-1 binaries
that ansible installed and that Pi-hole v6 broke (armv6 vs GOARM=7 + v6
REST API rewrite).

Constrained off oracle so probes use the LAN, not WireGuard.

Password sourced from Vault at `secret/pihole/green` (both pihole nodes share
the same password since the post-takeover rotation).
