# -------------------------------------------------------------------------------
# cdktf-ops-read.token.hcl
# Read-only token for dashboards/auditors
# -------------------------------------------------------------------------------
Name     = "ops-read"
Type     = "client"
Policies = ["ops-read", "system-deny"]
