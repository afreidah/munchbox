# Patroni policy - PostgreSQL HA cluster coordination
# Requires session management for leader election and KV for cluster state

session_prefix "" {
  policy = "write"
}

key_prefix "service/munchbox-postgres" {
  policy = "write"
}

service_prefix "postgres" {
  policy = "write"
}

service "patroni" {
  policy = "write"
}

node_prefix "" {
  policy = "read"
}
