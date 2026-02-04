# FlareSolverr

Headless browser proxy that solves Cloudflare anti-bot challenges on behalf
of Prowlarr. Many indexer sites use Cloudflare protection, making direct API
access impossible without a browser-based solver. Internal-only service with
no Traefik exposure. Runs on an Oracle Cloud ARM node to offload the headless
browser workload from the main cluster.
