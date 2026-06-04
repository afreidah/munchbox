# -----------------------------------------------------------------------------
# TEMPORAL-CONFIG MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------

provider "temporal" {
  host     = var.temporal_host
  port     = var.temporal_port
  insecure = var.temporal_insecure
}
