# Temporal Workflows

Temporal-based automated backup, vulnerability scanning, and cleanup
system. Each domain has its own dedicated worker and task queue, with
periodic trigger jobs that submit workflows on schedule.

## Architecture

Each workflow domain (backup, trivy scan, cleanup) runs as an independent
Temporal worker with its own container image, task queue, and Nomad
service job. Triggers are lightweight batch jobs that start a workflow via
the Temporal API and exit. The trigger binary is shared across all
domains and bundled into the backup-worker image.

## Jobs

| Job                      | Type    | Image           | Task Queue          | Schedule    | Purpose                                |
|--------------------------|---------|-----------------|---------------------|-------------|----------------------------------------|
| backup-worker            | service | backup-worker   | backup-task-queue   | Always-on   | Nomad, Consul, PostgreSQL, registry snapshots + S3 upload |
| trivy-scan-worker        | service | trivy-scan-worker | trivy-task-queue  | Always-on   | Container image vulnerability scanning |
| cleanup-worker           | service | cleanup-worker  | cleanup-task-queue  | Always-on   | Orphaned data directory removal via SSH |
| temporal-backup-trigger  | batch   | backup-worker   | --                  | Daily 2 AM  | Triggers backup workflow               |
| temporal-trivy-trigger   | batch   | backup-worker   | --                  | Daily 3 AM  | Triggers trivy scan workflow           |
| temporal-cleanup-trigger | batch   | backup-worker   | --                  | Daily 5 AM  | Triggers cleanup workflow              |
| temporal-registry-gc-trigger | batch | backup-worker | --                  | Weekly Sun 2 AM | Triggers Docker Registry GC workflow (scales registry to 0, runs `registry garbage-collect`, scales back to 1) |

## Data Flow

**Backup** -- Snapshots Nomad and Consul Raft state, dumps all PostgreSQL
databases (pg_dumpall), tarballs the container registry. Each backup is
stored locally on the gdrive NFS mount and uploaded to S3 for off-site
redundancy. Old backups are cleaned up based on retention policy (7 days
local, 30 days S3).

**Trivy Scan** -- Discovers running Docker images from the Nomad API,
scans each through the Trivy server in parallel batches, and stores CVE
results in PostgreSQL for the trivy-dashboard.

**Cleanup** -- SSHes to each Nomad client node, identifies job data
directories that no longer correspond to running allocations, and removes
those older than the grace period. Optionally prunes unused Docker images.

## Observability

All workers and triggers emit OpenTelemetry traces to Tempo with proper
service graph edges (nomad, consul, postgres, s3-orchestrator,
trivy-server). Workers expose Prometheus metrics on port 9090 for SDK
metrics (workflow/activity latency, retry counts, task queue depth).
Structured JSON logging via slog to stdout for Alloy/Loki collection.

## Notable Configuration

- Triggers pinned to bare metal nodes (Oracle has unreliable WAN for
  Temporal gRPC)
- Cleanup trigger runs in live mode (`DRY_RUN=false`) with a 7-day grace
  period
- Backup worker pinned to nomad-client-03 for gdrive mount access
- Cleanup worker needs SSH keys and host CA cert from Vault
- All secrets injected via Vault workload identity

## Dependencies

- **Temporal** -- workflow orchestration engine
- **Patroni** -- databases being backed up and trivy scan results stored
- **Trivy Server** -- vulnerability scanning API
- **Docker Registry** -- registry data backup source
- **S3 Orchestrator** -- off-site backup storage
- **Vault** -- Nomad/Consul tokens, database credentials, SSH keys
- **Tempo** -- distributed tracing
- **Prometheus** -- SDK metrics scraping
