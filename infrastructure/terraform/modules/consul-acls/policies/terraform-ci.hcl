# Terraform CI Policy
# Allows CI to manage terraform state in Consul KV and acquire state locks

# KV access for terraform state storage
key_prefix "terraform/" {
  policy = "write"
}

# Session permissions for state locking
session_prefix "" {
  policy = "write"
}
