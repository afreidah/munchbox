# -----------------------------------------------------------------------------
# RAMBLE ENV HELPER
# -----------------------------------------------------------------------------
#
# Publishes packs and jobs to Ramble under the afreidah namespace. The token
# comes from TF_VAR_ramble_token, which munchbox-env.sh reads from
# secret/ramble. An entry that already exists on Ramble is imported before its
# first apply.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//ramble"
}

inputs = {
  ramble_token = get_env("TF_VAR_ramble_token", "")
  namespace    = "afreidah"

  resources = {
    "nomad-pack-s3-orchestrator" = {
      type           = "pack"
      repository_url = "https://github.com/afreidah/nomad-pack-s3-orchestrator"
      description    = "Nomad pack for s3-orchestrator, one S3 endpoint over many S3-compatible backends with replication, read failover and per-backend usage limits. Published from afreidah/s3-orchestrator on each release."
      license        = "MIT"
      version        = "v0.191.0"

      tags = [
        "s3",
        "data-replication",
        "devops",
        "homelab",
        "object-storage",
        "self-hosted",
        "storage-orchestrator",
        "minio",
        "cloud-storage",
        "failover",
        "multi-cloud",
        "hashicorp-nomad",
        "nomad",
        "nomad-pack",
      ]
    }

    "s3-orchestrator" = {
      type           = "job"
      repository_url = "https://github.com/afreidah/nomad-job-s3-orchestrator"
      file_path      = "s3-orchestrator.nomad.hcl"
      description    = "Storage orchestration layer presenting many S3/blob providers as a single S3 endpoint, keeping a configurable number of copies across them with read failover, plus optional per-backend byte, request, ingress and egress limits, zstd compression and envelope encryption"
      license        = "MIT"
      version        = "v0.191.0"

      tags = [
        "postgres",
        "s3",
        "sqlite",
        "backup-tool",
        "data-replication",
        "devops",
        "homelab",
        "object-storage",
        "self-hosted",
        "storage-orchestrator",
        "distributed-systems",
        "minio",
        "quota-management",
        "reverse-proxy",
        "cloud-storage",
        "compression",
        "golang",
        "encryption",
        "failover",
        "multi-cloud",
      ]
    }
  }
}
