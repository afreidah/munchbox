# -----------------------------------------------------------------------------
# ALERT-RULES MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Writes one Consul KV entry per alert-group YAML. The consuming job's
# consul-template watches its own `<system>/alerts/` prefix and concatenates the
# group bodies into the rule file that job reads, so editing a YAML file and
# running `terragrunt apply` propagates without a nomad redeploy.
#
# Serves every alerting system that reads rules this way; the prefix in each
# key decides which job picks a group up.
# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# ALERT GROUPS - one KV entry per group
# -------------------------------------------------------------------------

resource "consul_keys" "groups" {
  for_each   = var.groups
  datacenter = var.datacenter

  key {
    path   = each.key
    value  = each.value
    delete = true
  }
}
