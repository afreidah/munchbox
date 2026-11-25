# -----------------------------------------------------------------------------
# FUNCTIONS-OCI ENV HELPER
# -----------------------------------------------------------------------------
#
# One OCI Functions application per consumer, each in a leaf under
# oci/functions/ named for it. Config is looked up from the catalog below by
# the calling directory's name. Each function's files map a path inside its
# archive to a file in functions-oci/<leaf>/ beside this file.
#
# The free tier is per tenancy: 2,000,000 invocations and 400,000 GB-seconds a
# month are shared across every leaf. Keys land in Vault through
# _env_helpers/vault-secrets.hcl, not from here.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//functions-oci"
}

dependency "networking" {
  config_path = "${get_repo_root()}/infrastructure/terragrunt/oci/networking"

  mock_outputs = {
    subnet_id = "ocid1.subnet.oc1.phx.mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

locals {
  root     = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  dir_name = basename(get_terragrunt_dir())
  config   = local.functions_oci_configs[local.dir_name]

  # --- keyed by terragrunt dir name ---
  #
  # vagabond dispatches function tasks here, and its live tests invoke
  # livetest to check the provider end to end: it replies under vagabond's
  # function contract, or sleeps past its 30 second timeout.
  functions_oci_configs = {
    vagabond = {
      user_email = "alex.freidah+vagabond-functions@gmail.com"
      purpose    = "vagabond-compute-broker"

      functions = {
        livetest = {
          runtime            = "python312.ol9"
          handler            = "func.handler"
          memory_in_mbs      = 128
          timeout_in_seconds = 30
          files              = { "function/func.py" = "livetest.py" }
        }
      }
    }
  }
}

inputs = {
  # --- OCI provider config; the empty provider block reads these off the
  #     environment, since a runner has no ~/.oci/config to fall back to ---
  tenancy_ocid = local.root.locals.oci_defaults.tenancy_ocid
  user_ocid    = local.root.locals.oci_defaults.user_ocid
  fingerprint  = local.root.locals.oci_defaults.fingerprint
  region       = local.root.locals.oci_defaults.region
  private_key  = get_env("OCI_PRIVATE_KEY", "")

  subnet_ids = [dependency.networking.outputs.subnet_id]
  name       = local.dir_name
  user_email = local.config.user_email

  # --- each archive path's contents, read from the leaf's directory here ---
  functions = {
    for name, f in local.config.functions : name => merge(f, {
      files = { for path, file_name in f.files : path => file("${get_repo_root()}/infrastructure/terragrunt/_env_helpers/functions-oci/${local.dir_name}/${file_name}") }
    })
  }

  tags = {
    Project   = "munchbox"
    ManagedBy = "terragrunt"
    Purpose   = local.config.purpose
  }
}
