# -----------------------------------------------------------------------------
# PI-HOLE DNS ENV HELPER
# -----------------------------------------------------------------------------
#
# Configures local DNS records in Pi-hole for split-horizon DNS.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/pihole-dns"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = local.root.locals.pihole_dns_inputs
