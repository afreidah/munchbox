# -----------------------------------------------------------------------------
# BOOTSTRAP MODULE - VARIABLES
# -----------------------------------------------------------------------------
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# PROVIDER SELECTION
# -----------------------------------------------------------------------------

variable "provider_type" {
  description = "Cloud/infrastructure provider: aws, oci, or proxmox"
  type        = string

  validation {
    condition     = contains(["aws", "oci", "proxmox"], var.provider_type)
    error_message = "Provider type must be 'aws', 'oci', or 'proxmox'."
  }
}

# -----------------------------------------------------------------------------
# NODE IDENTITY
# -----------------------------------------------------------------------------

variable "name" {
  description = "Name of the node"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "Name must be between 1 and 64 characters."
  }
}

variable "datacenter" {
  description = "Datacenter name for Nomad/Consul"
  type        = string
  default     = "dc1"
}

variable "node_class" {
  description = "Nomad node class (e.g., 'cloud', 'onprem', 'arm')"
  type        = string
  default     = "cloud"
}

variable "node_pool" {
  description = "Nomad node pool (leave empty for default)"
  type        = string
  default     = ""
}

variable "node_meta" {
  description = "Additional Nomad node metadata"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# COMPUTE RESOURCES
# -----------------------------------------------------------------------------

variable "cpu" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 4
}

variable "disk_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

# -----------------------------------------------------------------------------
# NETWORKING
# -----------------------------------------------------------------------------

variable "create_network" {
  description = "Create new network resources (false to use existing)"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC/VCN (when creating network)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "existing_subnet_id" {
  description = "Existing subnet ID (when create_network = false)"
  type        = string
  default     = null
}

variable "existing_security_group_id" {
  description = "Existing security group ID (when create_network = false)"
  type        = string
  default     = null
}

variable "existing_security_group_ids" {
  description = "List of existing security group IDs (overrides single ID)"
  type        = list(string)
  default     = null
}

# -----------------------------------------------------------------------------
# SECURITY RULES
# -----------------------------------------------------------------------------

variable "allow_ssh" {
  description = "Allow SSH from CIDR"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allow_wireguard" {
  description = "Allow WireGuard from CIDR"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allow_icmp" {
  description = "Allow ICMP from CIDR"
  type        = string
  default     = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# WIREGUARD CONFIGURATION
# -----------------------------------------------------------------------------

variable "wireguard_private_key" {
  description = "WireGuard private key for this node"
  type        = string
  sensitive   = true
}

variable "wireguard_address" {
  description = "WireGuard IP address for this node (without /24)"
  type        = string
}

variable "wireguard_subnet" {
  description = "WireGuard subnet CIDR (for security rules)"
  type        = string
  default     = "10.200.0.0/24"
}

variable "wireguard_server_public_key" {
  description = "WireGuard public key of the homelab server"
  type        = string
}

variable "wireguard_endpoint" {
  description = "WireGuard endpoint of homelab (e.g., 'home.example.com:51820')"
  type        = string
}

variable "wireguard_allowed_ips" {
  description = "WireGuard allowed IPs (networks reachable via tunnel)"
  type        = string
  default     = "10.200.0.0/24, 192.168.68.0/24"
}

# -----------------------------------------------------------------------------
# CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------

variable "consul_servers" {
  description = "List of Consul server addresses (via WireGuard)"
  type        = list(string)
  default     = ["10.200.0.1"]
}

variable "nomad_servers" {
  description = "List of Nomad server addresses (via WireGuard)"
  type        = list(string)
  default     = ["10.200.0.1:4647"]
}

variable "consul_integration" {
  description = "Enable Nomad-Consul integration"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SOFTWARE VERSIONS
# -----------------------------------------------------------------------------

variable "consul_version" {
  description = "Consul version to install"
  type        = string
  default     = "1.17.0"
}

variable "nomad_version" {
  description = "Nomad version to install"
  type        = string
  default     = "1.7.0"
}

# -----------------------------------------------------------------------------
# DOCKER CONFIGURATION
# -----------------------------------------------------------------------------

variable "allow_privileged_docker" {
  description = "Allow privileged Docker containers in Nomad"
  type        = bool
  default     = false
}

variable "docker_user" {
  description = "User to add to docker group (e.g., 'ubuntu')"
  type        = string
  default     = "ubuntu"
}

# -----------------------------------------------------------------------------
# PROVIDER-SPECIFIC CONFIGURATION
# -----------------------------------------------------------------------------

variable "aws_config" {
  description = "AWS-specific configuration"
  type = object({
    availability_zones = list(string)
    instance_type      = optional(string)
    architecture       = optional(string)
    spot_type          = optional(string)
    assign_elastic_ip  = optional(bool)
  })
  default = null
}

variable "oci_config" {
  description = "OCI-specific configuration"
  type = object({
    compartment_id      = string
    availability_domain = string
    shape               = optional(string)
  })
  default = null
}

variable "proxmox_config" {
  description = "Proxmox-specific configuration"
  type = object({
    target_node    = string
    vmid           = number
    template_name  = optional(string)
    disk_storage   = optional(string)
    network_bridge = optional(string)
  })
  default = null
}

# -----------------------------------------------------------------------------
# TAGS
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
