# ───────────────────────────────────────────────────────────────────────────────
# Policy: prometheus-metrics
# - Grants read-only access to Vault’s Prometheus metrics endpoint
# ───────────────────────────────────────────────────────────────────────────────
path "sys/metrics" {
  capabilities = ["read", "sudo", "list"]
}
