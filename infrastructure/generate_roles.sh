#!/bin/bash
# Generate all Ansible roles

ROLES_DIR="ansible/roles"

# Create role directories
for role in common proxmox-cluster ceph-cluster consul nomad dns storage; do
  mkdir -p "$ROLES_DIR/$role"/{tasks,templates,handlers,defaults}
done

echo "Role directories created successfully"
ls -la "$ROLES_DIR"
