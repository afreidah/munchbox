# -------------------------------------------------------------------------------
#  cdktf/infra/vault-policy/cdktf-waypoint-runner-read.hcl
#
#  Purpose:
#    Allow the waypoint-runner task (via Bao) to read the server token stored at
#    secret/system-services/waypoint_server_token (KV v2 path)
# -------------------------------------------------------------------------------

path "secret/data/system-services/waypoint_server_token" {
  capabilities = ["read"]
}
