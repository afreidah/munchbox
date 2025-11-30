# Temporal Backup Worker - Containerized Deployment

Automated backup system for HashiCorp infrastructure using Temporal workflows and Docker containers.

## Overview

This project creates scheduled snapshots of:
- **Nomad** cluster state (jobs, allocations, ACLs)
- **Consul** cluster state (KV store, services, ACLs)
- **OpenBao** cluster state (secrets, policies, auth methods)

Snapshots are stored on `/mnt/gdrive` with 7-day retention.

## Architecture

### Components

1. **Worker** (Long-running service)
   - Listens on Temporal task queue for backup workflows
   - Executes snapshot activities when triggered
   - Must run on node with `/mnt/gdrive` access
   - Deployed as Nomad service job

2. **Trigger** (Periodic batch job)
   - Initiates backup workflow execution
   - Runs daily at 2 AM Pacific time
   - Blocks until workflow completes
   - Deployed as Nomad periodic batch job

### Docker Image

Single multi-stage image contains:
- `temporal-backup-worker` - Worker binary
- `temporal-backup-trigger` - Trigger binary
- `nomad` CLI - For cluster snapshots
- `consul` CLI - For cluster snapshots
- `bao` CLI - For OpenBao snapshots

## Building

### Local Build

Build for single architecture:
```bash
# x86_64
make docker-build

# arm64
make docker-build-arm
```

Build for both architectures:
```bash
make docker-build-all
```

### Push to Registry

Configure registry (default: `localhost:5000`):
```bash
export DOCKER_REGISTRY=your-registry.example.com
```

Push images:
```bash
# Single architecture
make docker-push

# Both architectures
make docker-push-all
```

### Custom Image Tag

```bash
make docker-build IMAGE_TAG=v1.0.0
make docker-push IMAGE_TAG=v1.0.0
```

## Deployment

### Prerequisites

1. **Temporal Server** running at `192.168.68.61:7233`
2. **Docker registry** accessible from Nomad nodes
3. **Host volume** `/mnt/gdrive` on backup worker node
4. **Vault secrets** for service authentication:
   ```
   kv/data/nomad/backup-worker:
     - nomad_token
     - consul_token
     - bao_token
   ```

### Deploy Worker

```bash
nomad job run backup-worker.nomad.hcl
```

The worker runs continuously on the `mccoy` node with access to `/mnt/gdrive`.

### Deploy Trigger

```bash
nomad job run backup-trigger.nomad.hcl
```

The trigger runs daily at 2 AM Pacific time.

### Manual Trigger

Dispatch backup manually:
```bash
nomad job dispatch temporal-backup-trigger
```

## Configuration

### Environment Variables

**Worker:**
- `TEMPORAL_ADDRESS` - Temporal server endpoint
- `NOMAD_TOKEN` - From Vault via template
- `CONSUL_HTTP_TOKEN` - From Vault via template
- `BAO_ADDR` - OpenBao server address
- `BAO_TOKEN` - From Vault via template
- `BAO_SKIP_VERIFY` - Skip TLS verification (true/false)

**Trigger:**
- `TEMPORAL_ADDRESS` - Temporal server endpoint

### Volumes

Worker requires:
```
/mnt/gdrive:/mnt/gdrive
```

### Snapshot Locations

Snapshots stored in:
- `/mnt/gdrive/nomad-snapshots/`
- `/mnt/gdrive/consul-snapshots/`
- `/mnt/gdrive/openbao-snapshots/`

File naming: `{service}-{timestamp}.snap`

Example: `nomad-20251129020000.snap`

## Testing

### Local Docker Run

Test worker:
```bash
make docker-run-worker
```

Test trigger:
```bash
make docker-run-trigger
```

### With Custom Environment

```bash
docker run --rm \
  -e TEMPORAL_ADDRESS=192.168.68.61:7233 \
  -e NOMAD_TOKEN=your-token \
  -e CONSUL_HTTP_TOKEN=your-token \
  -e BAO_ADDR=https://openbao.service.consul:8200 \
  -e BAO_TOKEN=your-token \
  -e BAO_SKIP_VERIFY=true \
  -v /mnt/gdrive:/mnt/gdrive \
  localhost:5000/temporal-backup-worker:latest worker
```

## Monitoring

### Check Worker Status

```bash
nomad job status temporal-backup-worker
```

### View Logs

```bash
# Worker logs
nomad alloc logs -f <worker-alloc-id>

# Trigger logs (latest run)
nomad job status temporal-backup-trigger
nomad alloc logs <trigger-alloc-id>
```

### Temporal UI

Monitor workflow executions:
```
http://192.168.68.61:8080/namespaces/default/workflows
```

### Verify Snapshots

```bash
ls -lh /mnt/gdrive/nomad-snapshots/
ls -lh /mnt/gdrive/consul-snapshots/
ls -lh /mnt/gdrive/openbao-snapshots/
```

## Troubleshooting

### Worker Not Starting

1. Check Docker image is available:
   ```bash
   docker pull localhost:5000/temporal-backup-worker:latest
   ```

2. Verify Temporal server connectivity:
   ```bash
   telnet 192.168.68.61 7233
   ```

3. Check Vault template rendering:
   ```bash
   nomad alloc exec <alloc-id> cat /secrets/env.txt
   ```

### Snapshots Failing

1. Check CLI tools are installed:
   ```bash
   nomad alloc exec <alloc-id> nomad version
   nomad alloc exec <alloc-id> consul version
   nomad alloc exec <alloc-id> bao version
   ```

2. Verify authentication tokens:
   ```bash
   nomad alloc exec <alloc-id> env | grep TOKEN
   ```

3. Check volume mount:
   ```bash
   nomad alloc exec <alloc-id> ls -la /mnt/gdrive
   ```

### Trigger Not Running

1. Check periodic job schedule:
   ```bash
   nomad job periodic status temporal-backup-trigger
   ```

2. Force manual run:
   ```bash
   nomad job dispatch temporal-backup-trigger
   ```

## Migration from Binary Deployment

If migrating from direct binary deployment:

1. **Build and push images:**
   ```bash
   make docker-build-all
   make docker-push-all
   ```

2. **Stop existing jobs:**
   ```bash
   nomad job stop temporal-backup-worker
   nomad job stop temporal-backup-trigger
   ```

3. **Deploy containerized jobs:**
   ```bash
   nomad job run backup-worker.nomad.hcl
   nomad job run backup-trigger.nomad.hcl
   ```

4. **Verify first backup:**
   ```bash
   nomad job dispatch temporal-backup-trigger
   ```

5. **Remove old binaries from nodes** (optional):
   ```bash
   for node in mccoy cabot stabler goren; do
     ssh root@$node "rm -f /usr/local/bin/temporal-backup-*"
   done
   ```

## Development

### Build Native Binaries

```bash
# x86_64
make worker
make trigger

# arm64
make worker-arm
make trigger-arm
```

### Run Locally (Native)

```bash
make run-worker
make run-trigger
```

### Dependencies

```bash
make deps
```

### Tests

```bash
make test
```

## Retention Policy

Snapshots are automatically cleaned up after 7 days by the `CleanupOldBackups` activity. To modify retention:

Edit `workflow.go`:
```go
err = workflow.ExecuteActivity(ctx, CleanupOldBackups, 14).Get(ctx, nil)
```

Rebuild and redeploy:
```bash
make docker-build-all
make docker-push-all
nomad job stop temporal-backup-worker
nomad job run backup-worker.nomad.hcl
```

## Author

Alex Freidah  
Project: Munchbox
