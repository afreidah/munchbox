# Trivy Server

Runs Aqua Trivy in persistent server mode to handle vulnerability scan
requests over HTTP. The backup worker and other clients call this server's
API instead of spawning individual CLI processes, which avoids redundant
database downloads and enables concurrent scanning.

## Notable Configuration

- Uses Redis as the vulnerability database cache backend, sharing the
  cluster-wide Redis Sentinel instance
- Canary deployment with auto-promote ensures zero-downtime updates

## Dependencies

- **Redis Sentinel** -- vulnerability database cache storage
- **Temporal backup worker** -- primary client submitting scan requests
