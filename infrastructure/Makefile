# -------------------------------------------------------------------------------
# Munchbox Infrastructure Makefile
#
# Project: Munchbox / Author: Alex Freidah
#
# Orchestrates infrastructure provisioning and configuration. Manages Proxmox
# VMs, Consul ACLs, Vault configuration, and Ansible deployments for the
# Munchbox homelab cluster.
# -------------------------------------------------------------------------------

.PHONY: help

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------

TERRAFORM_PROXMOX := cd terraform/proxmox && terraform
TERRAFORM_CONSUL := cd terraform/consul-acls && terraform
TERRAFORM_VAULT := cd terraform/vault-config && terraform

# -------------------------------------------------------------------------
# Help
# -------------------------------------------------------------------------

help:
	@echo "==============================================================================="
	@echo "Munchbox Infrastructure Management"
	@echo "==============================================================================="
	@echo ""
	@echo "Quick Start (adding a new node):"
	@echo "  1. Edit nodes.yml to add your new VM/host"
	@echo "  2. make generate              - Regenerate inventory and tfvars"
	@echo "  3. make tf-apply              - Provision new VMs (skip for bare-metal)"
	@echo "  4. make add-node VM=hostname  - Configure and join the cluster"
	@echo ""
	@echo "Configuration Generation (from nodes.yml):"
	@echo "  make generate      - Generate Ansible inventory and Terraform vars"
	@echo "  make show-nodes    - Display current node configuration"
	@echo ""
	@echo "Node Management:"
	@echo "  make add-node VM=name    - Provision a new node (VM or bare-metal)"
	@echo "  make add-vm VM=name      - Add VM: generate + tf-apply + add-node"
	@echo ""
	@echo "Proxmox VM Provisioning:"
	@echo "  make tf-init       - Initialize Proxmox Terraform"
	@echo "  make tf-plan       - Preview VM changes"
	@echo "  make tf-apply      - Provision VMs"
	@echo "  make tf-output     - Show VM details"
	@echo "  make tf-destroy    - Destroy all VMs"
	@echo "  make clean         - Clean Terraform state files"
	@echo ""
	@echo "Consul ACL Management:"
	@echo "  make consul-prereqs     - Copy certs and enable Vault KV"
	@echo "  make consul-acl-init    - Initialize Consul ACL Terraform"
	@echo "  make consul-acl-plan    - Preview ACL changes"
	@echo "  make consul-acl-apply   - Apply ACL configuration"
	@echo "  make consul-acl-output  - Show ACL outputs"
	@echo "  make consul-acl-destroy - Remove ACL configuration"
	@echo ""
	@echo "Vault Configuration:"
	@echo "  make vault-config-init  - Initialize Vault config Terraform"
	@echo "  make vault-config-plan  - Preview Vault changes"
	@echo "  make vault-config-apply - Apply Vault configuration"
	@echo "==============================================================================="

# -------------------------------------------------------------------------
# Proxmox VM Provisioning
# -------------------------------------------------------------------------

tf-init:
	@echo "==> Initializing Terraform..."
	$(TERRAFORM_PROXMOX) init

tf-plan:
	@echo "==> Planning VM provisioning..."
	$(TERRAFORM_PROXMOX) plan

tf-apply:
	@echo "==> Provisioning VMs..."
	$(TERRAFORM_PROXMOX) apply -auto-approve
	@echo ""
	@echo "==> VMs created! Waiting for cloud-init to complete..."
	@echo "    (This takes ~2 minutes)"
	@sleep 120
	@echo ""
	@echo "==> Generating Ansible inventory..."
	$(TERRAFORM_PROXMOX) output -raw ansible_inventory > ansible/inventory/nomad-cluster.ini || true
	@echo ""
	@echo "==> Done! VMs are ready."
	@echo ""
	@echo "Next steps:"
	@echo "  - Verify: ssh root@192.168.68.69"
	@echo "  - Run Ansible: cd ansible && ansible-playbook playbooks/nomad-cluster.yml"

tf-output:
	@echo "==> VM Details:"
	$(TERRAFORM_PROXMOX) output

tf-destroy:
	@echo "==> WARNING: This will destroy all VMs!"
	@echo "==> Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	$(TERRAFORM_PROXMOX) destroy -auto-approve

clean:
	@echo "==> Cleaning Terraform state..."
	@rm -rf terraform/proxmox/.terraform
	@rm -f terraform/proxmox/terraform.tfstate*
	@rm -f terraform/proxmox/.terraform.lock.hcl
	@echo "==> Clean complete!"

# -------------------------------------------------------------------------
# Consul ACL Management
# -------------------------------------------------------------------------

consul-prereqs:
	@echo "==> Setting up prerequisites for Consul ACL Terraform..."
	@mkdir -p ~/.munchbox
	@echo "==> Copying Consul CA certificate from stabler..."
	@scp root@stabler:/etc/consul.d/tls/ca-chain.crt ~/.munchbox/
	@echo "==> Enabling Vault KV v2 secrets engine..."
	@ssh root@stabler 'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$$(jq -r .root_token /tmp/vault-init.json) vault secrets enable -path=secret kv-v2' || true
	@echo ""
	@echo "==> Prerequisites complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. cd terraform/consul-acls"
	@echo "  2. ./bootstrap-acls.sh"
	@echo "  3. source ./setup-env.sh"
	@echo "  4. terraform init"
	@echo "  5. terraform apply"

consul-acl-init:
	@echo "==> Initializing Consul ACL Terraform..."
	$(TERRAFORM_CONSUL) init

consul-acl-plan:
	@echo "==> Planning Consul ACL changes..."
	$(TERRAFORM_CONSUL) plan

consul-acl-apply:
	@echo "==> Applying Consul ACL configuration..."
	$(TERRAFORM_CONSUL) apply

consul-acl-output:
	@echo "==> Consul ACL Terraform outputs:"
	$(TERRAFORM_CONSUL) output

consul-acl-destroy:
	@echo "==> WARNING: This will remove all ACL policies and tokens!"
	@echo "==> Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	$(TERRAFORM_CONSUL) destroy

# -------------------------------------------------------------------------
# Vault Configuration
# -------------------------------------------------------------------------

vault-config-init:
	@echo "==> Initializing Vault Config Terraform..."
	$(TERRAFORM_VAULT) init

vault-config-plan:
	@echo "==> Planning Vault Config changes..."
	$(TERRAFORM_VAULT) plan

vault-config-apply:
	@echo "==> Applying Vault configuration..."
	$(TERRAFORM_VAULT) apply

vault-config-output:
	@echo "==> Vault Config Terraform outputs:"
	$(TERRAFORM_VAULT) output

vault-config-destroy:
	@echo "==> WARNING: This will remove Vault configuration!"
	@echo "==> Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	$(TERRAFORM_VAULT) destroy

# -------------------------------------------------------------------------
# Utility Commands
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Configuration Generation (from nodes.yml)
# -------------------------------------------------------------------------

.PHONY: generate show-nodes

generate:
	@echo "==> Generating configuration from nodes.yml..."
	@python3 scripts/generate-inventory.py
	@python3 scripts/generate-tfvars.py
	@echo ""
	@echo "==> Configuration generated successfully!"
	@echo "    - Ansible inventory: ansible/inventory/hosts.yml"
	@echo "    - Terraform vars: terraform/proxmox/vms.auto.tfvars"

show-nodes:
	@echo "==> Current Node Configuration (from nodes.yml):"
	@echo ""
	@python3 -c "import yaml; d=yaml.safe_load(open('nodes.yml')); \
		print('Proxmox Hosts:'); \
		[print(f'  {k}: {v[\"ip\"]}') for k,v in d.get('proxmox_hosts',{}).items()]; \
		print('\nBare-Metal Nodes:'); \
		[print(f'  {k}: {v[\"ip\"]} ({v.get(\"arch\",\"amd64\")})') for k,v in d.get('bare_metal',{}).items()]; \
		print('\nVMs:'); \
		[print(f'  {k}: {v[\"ip\"]} on {v[\"proxmox_host\"]} (vmid={v[\"vmid\"]})') for k,v in d.get('vms',{}).items()]"

# -------------------------------------------------------------------------
# Node Management
# -------------------------------------------------------------------------

.PHONY: add-node add-vm

add-node:
ifndef VM
	$(error VM is not set. Usage: make add-node VM=nomad-client-04)
endif
	@echo "==> Provisioning node: $(VM)"
	cd ansible && ansible-playbook playbooks/add-node.yml -e target_host=$(VM)

add-vm:
ifndef VM
	$(error VM is not set. Usage: make add-vm VM=nomad-client-04)
endif
	@echo "==> Adding new VM: $(VM)"
	@echo "==> Step 1/3: Generating configuration..."
	$(MAKE) generate
	@echo ""
	@echo "==> Step 2/3: Provisioning VM in Proxmox..."
	$(TERRAFORM_PROXMOX) apply -auto-approve
	@echo ""
	@echo "==> Waiting 60s for VM to boot..."
	@sleep 60
	@echo ""
	@echo "==> Step 3/3: Configuring node..."
	cd ansible && ansible-playbook playbooks/add-node.yml -e target_host=$(VM)
	@echo ""
	@echo "==> VM $(VM) added successfully!"
