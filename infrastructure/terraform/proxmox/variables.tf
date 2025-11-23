# -------------------------------------------------------------------------------
# Proxmox VM Provisioning - Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Variable definitions for VM provisioning. Actual values should be set in
# terraform.tfvars (gitignored).
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Proxmox Connection
# -------------------------------------------------------------------------------

variable "proxmox_api_url" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.68.65:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (format: user@pam!tokenname)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

# -------------------------------------------------------------------------------
# VM Template
# -------------------------------------------------------------------------------

variable "template_name" {
  description = "Name of the VM template to clone (Debian cloud-init template)"
  type        = string
  default     = "debian-12-cloudinit"
}

# -------------------------------------------------------------------------------
# Ansible User Configuration
# -------------------------------------------------------------------------------

variable "ansible_user" {
  description = "Username for Ansible SSH access"
  type        = string
  default     = "ansible"
}

variable "ansible_password" {
  description = "Password for ansible user (only for initial bootstrap)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for ansible user"
  type        = string
}

# -------------------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------------------

variable "gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "192.168.68.1"
}

variable "nameservers" {
  description = "DNS nameservers for VMs"
  type        = list(string)
  default     = ["192.168.68.62", "192.168.68.64"]
}

variable "search_domain" {
  description = "DNS search domain"
  type        = string
  default     = "munchbox.cc"
}
