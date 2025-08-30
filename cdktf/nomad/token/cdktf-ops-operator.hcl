# -------------------------------------------------------------------------------
# cdktf-ops-operator.token.hcl
# SRE/operator token for on-call and routine ops
# -------------------------------------------------------------------------------
Name     = "ops-operator"
Type     = "client"
Policies = ["ops-operator", "system-deny"]

