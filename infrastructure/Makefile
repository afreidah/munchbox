# -------------------------------------------------------------------------------
# Munchbox Infrastructure Makefile
#
# Project: Munchbox / Author: Alex Freidah
#
# Simplified workflow for Proxmox ISO installation method.
# -------------------------------------------------------------------------------

.PHONY: help tf-init tf-plan tf-apply tf-destroy tf-output clean

TERRAFORM := cd terraform/proxmox && terraform

# -------------------------------------------------------------------------
# Help
# -------------------------------------------------------------------------

help:
	@echo "Munchbox Infrastructure - Simplified Workflow"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Proxmox installed from ISO on all nodes"
	@echo "  - Proxmox cluster formed manually"
	@echo "  - Ceph configured manually"
	@echo "  - Debian cloud-init template created"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make tf-init    - Initialize Terraform"
	@echo "  make tf-plan    - Preview VM changes"
	@echo "  make tf-apply   - Create VMs"
	@echo "  make tf-output  - Show VM details"
	@echo "  make tf-destroy - Destroy all VMs"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. Configure terraform/proxmox/terraform.tfvars"
	@echo "  2. make tf-init"
	@echo "  3. make tf-apply"
	@echo "  4. Wait 2 minutes for cloud-init"
	@echo "  5. SSH to VMs and install Nomad/Consul"

# -------------------------------------------------------------------------
# Terraform Workflow
# -------------------------------------------------------------------------

tf-init:
	@echo "==> Initializing Terraform..."
	$(TERRAFORM) init

tf-plan:
	@echo "==> Planning VM provisioning..."
	$(TERRAFORM) plan

tf-apply:
	@echo "==> Provisioning VMs..."
	$(TERRAFORM) apply -auto-approve
	@echo ""
	@echo "==> VMs created! Waiting for cloud-init to complete..."
	@echo "    (This takes ~2 minutes)"
	@sleep 120
	@echo ""
	@echo "==> Generating Ansible inventory..."
	$(TERRAFORM) output -raw ansible_inventory > ../../ansible/inventory/nomad-cluster.ini || true
	@echo ""
	@echo "==> Done! VMs are ready."
	@echo ""
	@echo "Next steps:"
	@echo "  - Verify: ssh ansible@192.168.68.70"
	@echo "  - Install Nomad/Consul manually or use Ansible"

tf-output:
	@echo "==> VM Details:"
	$(TERRAFORM) output

tf-destroy:
	@echo "==> WARNING: This will destroy all VMs!"
	@echo "==> Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	$(TERRAFORM) destroy -auto-approve

# -------------------------------------------------------------------------
# Utility Commands
# -------------------------------------------------------------------------

clean:
	@echo "==> Cleaning Terraform state..."
	@rm -rf terraform/proxmox/.terraform
	@rm -f terraform/proxmox/terraform.tfstate*
	@rm -f terraform/proxmox/.terraform.lock.hcl

ssh-server-%:
	@ssh ansible@192.168.68.$(shell expr 69 + $*)

ssh-client-%:
	@ssh ansible@192.168.68.$(shell expr 79 + $*)
