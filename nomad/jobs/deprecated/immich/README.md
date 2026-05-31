# Immich

Self-hosted photo and video management platform with machine learning
capabilities for face recognition, object detection, and smart search.
Leverages the existing Patroni PostgreSQL cluster (with pgvector) and
Redis Sentinel for storage and caching rather than running dedicated
instances.

## Architecture

The job runs in a single bridge-mode task group with three tasks sharing
a network namespace. The server task handles the API and web interface.
The machine-learning task runs CUDA-accelerated inference models for
facial recognition and classification. A prestart init-storage task
ensures directory structure and permissions are correct before the
services start.

Photos are stored on the shared NFS mount (`/mnt/gdrive/immich`) for
durability. ML model cache also lives on NFS to avoid re-downloading
models after restarts.

## Components

| Task             | Role                           | Lifecycle |
|------------------|--------------------------------|-----------|
| init-storage     | Create directories, fix perms  | prestart  |
| server           | API server and web interface   | main      |
| machine-learning | CUDA-accelerated ML inference  | main      |

## Notable Configuration

- Pinned to nomad-client-04 (has NVIDIA GPU) for ML acceleration
- NVIDIA device passthrough with the nvidia runtime driver
- ML task uses the CUDA-specific image variant
- No oauth2-proxy on photo routes -- Immich has its own auth system
- Bridge mode with explicit DNS for Consul service discovery

## Dependencies

- **Patroni** -- PostgreSQL with pgvector extension for ML embeddings
- **Redis Sentinel** -- session cache and job queue
