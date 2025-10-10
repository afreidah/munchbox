#!/bin/bash

# Define your cluster nodes and service names
CONSUL_NODES=("cabot" "mccoy" "goren" "stabler")
VAULT_NODES=("mccoy")
NOMAD_NODES=("cabot" "mccoy" "goren" "stabler")

# 1. Shut down Nomad agents and servers gracefully
echo "Shutting down Nomad agents and servers..."
for node in "${NOMAD_NODES[@]}"; do
  echo "Stopping Nomad on $node..."
  ssh "$node" "sudo systemctl stop nomad"
done

# 2. Step down the active Vault node and then shut down all Vault nodes
echo "Stepping down active Vault node and shutting down Vault servers..."
# Identify the active Vault node (requires Vault operator access)
# For simplicity, we'll assume a method to find the active node or step down all
# In a real scenario, you'd target the active node with 'vault operator step-down'
for node in "${VAULT_NODES[@]}"; do
  echo "Shutting down Vault on $node..."
  ssh "$node" "sudo systemctl stop vault"
done

# 3. Shut down Consul agents and servers gracefully
echo "Shutting down Consul agents and servers..."
for node in "${CONSUL_NODES[@]}"; do
  echo "Stopping Consul on $node..."
  ssh "$node" "sudo systemctl stop consul"
done

echo "Cluster shutdown complete."
