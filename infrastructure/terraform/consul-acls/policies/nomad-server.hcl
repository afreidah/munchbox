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

query_prefix "" {
  policy = "read"
}

key_prefix "" {
  policy = "write"
}
