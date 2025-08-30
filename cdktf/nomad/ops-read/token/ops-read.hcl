# ops-read.hcl
# Nomad token granting access to the ops-read policy

Name     = "ops-read"
Type     = "client"
Policies = ["ops-read"]
