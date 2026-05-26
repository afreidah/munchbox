# -----------------------------------------------------------------------------
# CONSUL-ACLS MODULE ENV HELPER
# -----------------------------------------------------------------------------
#
# Include this in terragrunt.hcl to provision Consul ACL policies and tokens,
# storing generated tokens in Vault KV for secure retrieval.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//consul-acls"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.consul_acls_inputs
