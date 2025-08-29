#####################################
# Prometheus Node Exporter Pack Configuration
# For use with: community/prometheus_node_exporter
#####################################

# Specify the Nomad region for job placement
region = "global"

# Specify the datacenters for job placement
datacenters = ["pi-dc"]

# Specify the Nomad node pool for this job
node_pool = "edge"

# Optional override for the job name
job_name = "node-exporter-edge"

# Network configuration for the node exporter group
node_exporter_group_network = {
  mode  = "host"
  ports = { 
    http = 9100 
  }
}

# Additional task configuration (e.g., version)
node_exporter_task_config = {
  version = "v1.8.2"
}

# Configure resources for the node exporter task
node_exporter_task_resources = {
  cpu    = 50    # MHz of CPU
  memory = 64    # MB of memory
}
