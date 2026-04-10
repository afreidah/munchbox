#!/bin/bash
# -------------------------------------------------------------------------------
# Shutdown Cluster - Graceful Cluster Shutdown
#
# Project: Munchbox / Author: Alex Freidah
#
# Performs graceful shutdown of the entire Munchbox cluster. Stops Nomad first,
# then Vault, then Consul to maintain proper dependency ordering.
# -------------------------------------------------------------------------------

# Define cluster nodes and service names
CONSUL_NODES=("cabot" "mccoy" "goren" "stabler")
VAULT_NODES=("mccoy" "goren" "stabler")
NOMAD_NODES=("nomad-client-01" "nomad-client-02" "goren" "stabler" "nomad-client-03" "nomad-client-04" "nomad-client-05")

echo "Shutting down Consul agents and servers..."
for node in "${CONSUL_NODES[@]}"; do
  echo "Stopping Consul on $node..."
  ssh "root@$node" "sudo systemctl start consul"
done

# 1. Shut down Nomad agents and servers gracefully
echo "Shutting down Nomad agents and servers..."
for node in "${NOMAD_NODES[@]}"; do
  echo "Stopping Nomad on $node..."
  #ssh "root@$node" "sudo systemctl stop nomad"
  ssh "root@$node" "sudo systemctl start nomad"
done

# 2. Step down the active Vault node and then shut down all Vault nodes
echo "Stepping down active Vault node and shutting down Vault servers..."
# Identify the active Vault node (requires Vault operator access)
# For simplicity, we'll assume a method to find the active node or step down all
# In a real scenario, you'd target the active node with 'vault operator step-down'
for node in "${VAULT_NODES[@]}"; do
  echo "Shutting down Vault on $node..."
  #ssh "root@$node" "sudo systemctl stop vault"
  ssh "root@$node" "sudo systemctl start vault"
done

# 3. Shut down Consul agents and servers gracefully
#echo "Shutting down Consul agents and servers..."
#for node in "${CONSUL_NODES[@]}"; do
#  echo "Stopping Consul on $node..."
#  ssh "root@$node" "sudo systemctl stop consul"
#done

echo "Cluster shutdown complete."
