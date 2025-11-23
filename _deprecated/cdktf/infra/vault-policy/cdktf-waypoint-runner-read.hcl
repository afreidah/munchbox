# -------------------------------------------------------------------------------
#  cdktf/infra/vault-policy/cdktf-waypoint-runner-read.hcl
#
#  Purpose:
#    Allow waypoint tasks (runner and bootstrap) to read/write the server token
#    stored at secret/system-services/waypoint_server_token (KV v2 path)
# -------------------------------------------------------------------------------

path "secret/data/system-services/waypoint_server_token" {
  capabilities = ["create", "read", "update"]
}
