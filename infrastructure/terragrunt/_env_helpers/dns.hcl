# -----------------------------------------------------------------------------
# DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Configures Cloudflare DNS records, tunnel routing, and rate limiting.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terraform/modules/dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.dns_inputs
