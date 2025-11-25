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
	@echo ""
	@echo "Utility Commands:"
	@echo "  make ssh-server-<n>     - SSH to nomad-server-03 (n=0)"
	@echo "  make ssh-client-<n>     - SSH to nomad-client-0[1-3] (n=1-3)"
	@echo ""
	@echo "Typical Workflow:"
	@echo "  1. Provision VMs:        make tf-apply"
	@echo "  2. Setup ACL prereqs:    make consul-prereqs"
	@echo "  3. Bootstrap ACLs:       cd terraform/consul-acls && ./bootstrap-acls.sh"
	@echo "  4. Setup environment:    cd terraform/consul-acls && source ./setup-env.sh"
	@echo "  5. Apply ACLs:           make consul-acl-apply"
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

ssh-server-%:
	@ssh root@192.168.68.$(shell expr 69 + $*)

ssh-client-%:
	@ssh root@192.168.68.$(shell expr 69 + $*)
