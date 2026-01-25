# Consul agent policy - allows agents to register themselves and services
node_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}
