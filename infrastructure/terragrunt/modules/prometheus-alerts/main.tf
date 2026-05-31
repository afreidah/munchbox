# -----------------------------------------------------------------------------
# PROMETHEUS-ALERTS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Writes one Consul KV entry per alert-group YAML. The prometheus job's
# consul-template watches the `prometheus/alerts/` prefix, concatenates the
# group bodies into /etc/prometheus/config/alert_rules.yml on disk, and
# SIGHUPs prom. Editing a YAML file + `terragrunt apply` propagates without
# a nomad redeploy.
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
