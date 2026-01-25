# Nomad server policy - full cluster orchestration
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

# Required for Consul Connect - allows Nomad to create service identity tokens
acl = "write"

query_prefix "" {
  policy = "read"
}

key_prefix "" {
  policy = "write"
}
