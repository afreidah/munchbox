#!/bin/bash
set -e

# Define node roles
declare -A NODES=(
  [stabler]="192.168.68.61|server"
  [goren]="192.168.68.60|server"
  [nomad-server-03]="192.168.68.69|server"
  [nomad-client-01]="192.168.68.70|client"
  [nomad-client-02]="192.168.68.72|client"
  [nomad-client-03]="192.168.68.71|client"
)

SERVER_IPS="192.168.68.61,192.168.68.60,192.168.68.69"

echo "=== FIXING CONSUL CLUSTER CONFIGURATION ==="
echo "Servers: stabler, goren, nomad-server-03"
echo "Clients: nomad-client-01, nomad-client-02, nomad-client-03"
echo ""

for node in "${!NODES[@]}"; do
  IFS='|' read -r ip role <<< "${NODES[$node]}"
  
  echo ">>> Processing $node ($ip) - Role: $role"
  
  if [ "$role" == "server" ]; then
    ssh root@"$node" << EOF
# Fix server config
sed -i 's/server = false/server = true/' /etc/consul.d/consul.hcl
sed -i 's/retry_join = \["[^"]*"\]/retry_join = ["192.168.68.60", "192.168.68.61", "192.168.68.69"]/' /etc/consul.d/consul.hcl
systemctl restart consul
sleep 2
echo "Consul restarted on $node"
EOF
  else
    ssh root@"$node" << EOF
# Fix client config
sed -i 's/server = true/server = false/' /etc/consul.d/consul.hcl
sed -i 's/retry_join = \["[^"]*"\]/retry_join = ["192.168.68.60", "192.168.68.61", "192.168.68.69"]/' /etc/consul.d/consul.hcl
systemctl restart consul
sleep 2
echo "Consul restarted on $node"
EOF
  fi
  
  echo "✓ $node fixed"
  echo ""
done

echo "=== VERIFYING CONSUL CLUSTER ==="
sleep 5

# Check from stabler
ssh root@stabler << 'EOF'
echo "Consul members:"
consul members
echo ""
echo "Raft peers:"
consul operator raft list-peers
EOF
