# -----------------------------------------------------------------------------
# NOMAD-CONFIG ENV HELPER
# -----------------------------------------------------------------------------
#
# Cluster-level Nomad scheduler + preemption + node-pool config. Only the
# "oracle" pool is managed here; on-prem nodes use the built-in "default"
# pool. Workload placement within a pool is driven by meta-tag constraints
# in job specs:
#
#   meta.role  = "ingress"   → goren, nomad-client-05
#   meta.gpu   = "true"      → nomad-client-04
#   meta.arch  = "arm64"     → oraclearm1, oraclearm2
#   meta.arch  = "amd64"     → all other nodes
#   meta.tier  = "micro"     → oraclenode1, oraclenode2
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//nomad-config"
}

inputs = {
  scheduler_algorithm             = "spread"
  memory_oversubscription_enabled = true

  preemption_config = {
    batch    = false
    service  = false
    sysbatch = false
    system   = true
  }

  node_pools = {
    "oracle" = {
      description = "Oracle Cloud nodes connected via WireGuard tunnel for remote/edge workloads"
    }
  }
}
