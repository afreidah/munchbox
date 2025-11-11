# -----------------------------------------------------------------------------
# TERRAGRUNT ROOT CONFIGURATION
# -----------------------------------------------------------------------------
#
# This root configuration file provides shared configuration for all Terragrunt
# modules in this repository.
#
# Directory Structure:
#   <environment>/<component>/terragrunt.hcl
#
# Features:
#   - Dynamic environment/component parsing
#   - Centralized environment-specific configuration
#   - Consistent naming/tagging conventions
#   - Shared backend and provider config generation
# -----------------------------------------------------------------------------

locals {
  repo_root       = abspath(get_repo_root())
  workdir         = abspath(get_original_terragrunt_dir())
  relative_path   = substr(local.workdir, length(local.repo_root) + 1, length(local.workdir) - (length(local.repo_root) + 1))

  # Parse directory structure: <terraform>/<environment>/<component>
  path_components = split("/", local.relative_path)
  environment     = length(local.path_components) > 1 ? local.path_components[1] : ""
  region          = ""
  component       = length(local.path_components) > 2 ? local.path_components[2] : ""

  name_prefix = "${local.environment}-${local.region}"

  env_config = {
    production = {
      nomad_version         = "1.10.3"
      consul_version        = "1.16.2"
      nomad_server_count    = 3
      nomad_client_count    = 5
      instance_type_server  = "bare-metal"
      instance_type_client  = "bare-metal"
      key_name              = null
      allowed_inbound_cidrs = ["0.0.0.0/0"]
    }
  }

  nomad_cluster_config = {
    scheduler = {
      memory_oversubscription_enabled = true
      scheduler_algorithm             = "binpack"
      preemption = {
        system_scheduler    = true
        service_scheduler   = false
        batch_scheduler     = false
        sysbatch_scheduler  = false
      }
    }

    namespaces = [
      { name = "default" },
      { name = "dev" },
    ]

    node_pools = {
      core = {
        description     = "Core services"
        scheduler_type  = "service"
        meta            = { layer = "core" }
        constraints     = [{
          attribute = "attr.node_class"
          operator  = "="
          value     = "core"
        }]
      }
    
      edge = {
        description     = "Edge workloads"
        scheduler_type  = "batch"
        meta            = { layer = "edge" }
        constraints     = [{
          attribute = "attr.node_class"
          operator  = "="
          value     = "utility"
        }]
      }
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "null" {}
provider "local" {}
provider "nomad" {
  address = "https://mccoy:4646"
}
EOF
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "consul" {
    address = "mccoy:8500"
    scheme  = "http"
    path    = "terraform/${local.environment}/${local.component}/state"
  }
}
EOF
}

terraform {
  extra_arguments "force_named_plan_out" {
    commands  = ["plan"]
    arguments = ["-out=plan.tfplan"]
  }
}

inputs = {
  environment        = local.environment
  component          = local.component
  region             = local.region
  name_prefix        = local.name_prefix
  nomad_cluster      = local.nomad_cluster_config

  common_tags = {
    Environment = local.environment
    Component   = local.component
    ManagedBy   = "Terragrunt"
    Terraform   = "true"
  }
}

