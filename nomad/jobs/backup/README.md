# Backup System

Temporal-based automated backup, vulnerability scanning, and cleanup
system. Four Nomad jobs work together through the Temporal workflow
engine: three periodic triggers submit workflows, and one long-running
worker executes them.

## Architecture

The triggers are lightweight batch jobs that run on a cron schedule. Each
trigger submits a workflow to the Temporal server and exits. The backup
worker is a persistent service that polls Temporal for pending workflows
and executes the actual work (database dumps, registry snapshots, image
scanning, disk cleanup).

All four jobs use the same container image
(`registry.munchbox.cc/temporal-backup-worker`), differentiated by the
command argument (`trigger` vs `worker`) and environment variables that
select the workflow type.

## Jobs

| Job                      | Type    | Schedule    | Purpose                              |
|--------------------------|---------|-------------|--------------------------------------|
| temporal-backup-trigger  | batch   | Daily 2 AM  | Triggers database and registry backup|
| temporal-trivy-trigger   | batch   | Daily 3 AM  | Triggers vulnerability scans         |
| temporal-cleanup-trigger | batch   | Daily 5 AM  | Triggers orphaned data cleanup       |
| temporal-backup-worker   | service | Always-on   | Executes all workflow types           |

## Data Flow

The backup workflow dumps all PostgreSQL databases and creates a tarball
of the Docker registry data, uploading everything to the gdrive NFS mount.
The trivy workflow enumerates running container images from the Nomad API,
scans each through the Trivy server, and writes results to the trivy
PostgreSQL database. The cleanup workflow removes orphaned allocation
directories older than 7 days and prunes unused Docker images.

## Notable Configuration

- Triggers pinned to bare metal nodes (Oracle has unreliable WAN for
  Temporal gRPC)
- Cleanup trigger runs in live mode (`DRY_RUN=false`) with a 7-day grace
  period
- Worker has broad access: gdrive mount, Nomad API token, Consul token,
  PostgreSQL root credentials, Redis password, SSH keys
- Worker pinned to nomad-client-03 for access to local Nomad data dirs
- All jobs send traces to Tempo via OpenTelemetry

## Dependencies

- **Temporal** -- workflow orchestration engine
- **Patroni** -- databases being backed up and scanned
- **Trivy Server** -- vulnerability scanning API
- **Docker Registry** -- registry data backup source
- **Vault** -- Nomad/Consul tokens, database credentials
