# -----------------------------------------------------------------------------
# CONSUL-KV MODULE
# -----------------------------------------------------------------------------
#
# Generic Consul KV writer: one consul_keys resource per path => value entry in
# var.keys, each with delete lifecycle so the set of keys is fully managed here.
# Callers supply both the paths and the (already-formatted) values; this module
# has no knowledge of what any key is for.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

resource "consul_keys" "this" {
  for_each   = var.keys
  datacenter = var.datacenter

  key {
    path   = each.key
    value  = each.value
    delete = true
  }
}
