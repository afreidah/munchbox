# -----------------------------------------------------------------------------
# GOSSIP-KEYS MODULE
#
# Project: Munchbox / Author: Alex Freidah
#
# Generates a base64 symmetric key per map entry, the shape Serf wants for
# gossip encryption in both Nomad and Consul. Vault-free: keys are sensitive
# outputs written to Vault by the vault-secrets leaf.
#
# Rotating a key here is a fleet-wide event -- every member of that gossip
# pool must carry the same key -- so entries are created once and left alone.
# An existing key is adopted with `terraform import`, never regenerated.
# -----------------------------------------------------------------------------

resource "random_bytes" "key" {
  for_each = var.keys

  length = each.value.byte_length

  # --- import records the value but resets generation args in state, which
  #     would otherwise force a replace and break the pool ---
  lifecycle {
    ignore_changes = [length]
  }
}
