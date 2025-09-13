# consul-policy/nomad-template-waypoint-read.hcl
# -------------------------------------------------------------------------------
# Read-only access for Nomad template rendering to Waypoint server token in KV.
# -------------------------------------------------------------------------------
key_prefix "system-services/" {
  policy = "read"
}

