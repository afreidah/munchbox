#!/bin/bash
# -------------------------------------------------------------------------------
# Generate Ansible Roles - Directory Scaffold Generator
#
# Project: Munchbox / Author: Alex Freidah
#
# Creates the standard Ansible role directory structure for all infrastructure
# roles. Run once during initial setup to scaffold the role hierarchy.
# -------------------------------------------------------------------------------

ROLES_DIR="ansible/roles"

# Create role directories
for role in common proxmox-cluster ceph-cluster consul nomad dns storage; do
  mkdir -p "$ROLES_DIR/$role"/{tasks,templates,handlers,defaults}
done

echo "Role directories created successfully"
ls -la "$ROLES_DIR"
