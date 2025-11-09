# --------------------------------------------------------------------------------
#  Hashi-UI — Consul Read-Only Policy
#
#  Purpose:
#    Allow Hashi-UI to read Consul catalog/health information so the Consul
#    sections of the UI can render. This mirrors your existing read policies
#    (e.g., prometheus-sd-read, traefik-catalog-read).
#
#  Notes:
#    - DO NOT add an `operator {}` block here; Consul policy syntax does not
#      support that (previous parser error came from that).
#    - Uncomment key_prefix if you want the UI to browse Consul KV, too.
# --------------------------------------------------------------------------------

# Single-agent read stanza (consistent with your style in other policies)
agent {
  policy = "read"
}

# Catalog/health read across the board
agent_prefix   "" { policy = "read" }
node_prefix    "" { policy = "read" }
service_prefix "" { policy = "read" }
query_prefix   "" { policy = "read" }

# enable KV browsing from UI
key_prefix "" { policy = "read" }

