# -----------------------------------------------------------------------------
# GOSSIP-KEYS MODULE - OUTPUTS
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

output "vault_data" {
  description = "Vault-ready keys keyed by name; the inner `key` is the base64 value a gossip config consumes."
  value = {
    for name, r in random_bytes.key : name => {
      key = r.base64
    }
  }
  sensitive = true
}
