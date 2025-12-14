# -------------------------------------------------------------------------------
# Prometheus Service Discovery Policy - Consul ACL
#
# Project: Munchbox / Author: Alex Freidah
#
# Grants Prometheus read access for service discovery and scrape target enumeration.
# -------------------------------------------------------------------------------

agent {
  policy = "read"
}

agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "read"
}

query_prefix "" {
  policy = "read"
}
