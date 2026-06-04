# Temporal Workflows

Temporal-based automated backup, vulnerability scanning, and cleanup
system. Each domain has its own dedicated worker and task queue; workflows
fire on cron from Temporal Schedules.

## Architecture

Each workflow domain (backup, trivy scan, cleanup) runs as an independent
Temporal worker with its own container image, task queue, and Nomad
service job. Workflows are started on schedule by Temporal Schedules
managed as code in the `infrastructure/terragrunt` repo
(`global/temporal-config`) -- the server fires them, so there are no
trigger jobs or trigger binary.

## Jobs

| Job               | Type    | Image             | Task Queue         | Purpose                                |
|-------------------|---------|-------------------|--------------------|----------------------------------------|
| backup-worker     | service | backup-worker     | backup-task-queue  | Nomad, Consul, PostgreSQL snapshots + S3 upload |
| trivy-scan-worker | service | trivy-scan-worker | trivy-task-queue   | Container image vulnerability scanning |
| cleanup-worker    | service | cleanup-worker    | cleanup-task-queue | Orphaned data removal + Docker registry GC |

Schedules (cron, in `temporal-config`): backup daily 1 AM, trivy daily
3 AM, cleanup daily 5 AM, registry GC weekly Sun 2 AM.

## Data Flow

**Backup** -- Snapshots Nomad and Consul Raft state and PostgreSQL (the
three legs run concurrently). PostgreSQL dumps cluster globals once, then
dumps each database to its own file with bounded concurrency. Each artifact
is stored locally on the gdrive NFS mount and uploaded to S3. Old backups
are cleaned up by retention (7 days local, 30 days S3).

**Trivy Scan** -- Discovers running Docker images from the Nomad API,
scans them through the Trivy server with bounded concurrency, and stores
CVE results in PostgreSQL for the trivy-dashboard.

**Cleanup** -- SSHes to each Nomad client node, identifies job data
directories that no longer correspond to running allocations, and removes
those older than the grace period. Optionally prunes unused Docker images.
The same worker also hosts the registry GC workflow.

## Observability

All workers emit OpenTelemetry traces to Tempo with proper service graph
edges (nomad, consul, postgres, s3-orchestrator, trivy-server). Workers
expose Prometheus metrics on port 9090 for SDK metrics (workflow/activity
latency, retry counts, task queue depth). Structured JSON logging via slog
to stdout for Alloy/Loki collection.

## Notable Configuration

- Cleanup schedule runs in live mode (`dry_run=false`) with a 7-day grace
  period
- Backup worker pinned to nomad-client-03 for gdrive mount access
- Cleanup worker needs SSH keys and host CA cert from Vault
- All secrets injected via Vault workload identity

## Dependencies

- **Temporal** -- workflow orchestration engine + schedules
- **Patroni** -- databases being backed up and trivy scan results stored
- **Trivy Server** -- vulnerability scanning API
- **Docker Registry** -- garbage-collected by the registry-gc workflow
- **S3 Orchestrator** -- off-site backup storage
- **Vault** -- Nomad/Consul tokens, database credentials, SSH keys
- **Tempo** -- distributed tracing
- **Prometheus** -- SDK metrics scraping
