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

# -----------------------------------------------------------------------------
# CHEF BOOTSTRAP
#
# Cloud-init drops these into /etc/cinc/* on first boot, then runs
# `cinc-client -j /etc/cinc/first_run.json` to register the node and
# converge its role. Everything past first-converge is owned by the chef
# cookbooks; these vars are only for the bootstrap moment.
# -----------------------------------------------------------------------------

variable "bootstrap_wireguard" {
  description = "Bring up wg0 in cloud-init so the node can reach 192.168.68.x (oracle nodes = true; proxmox / bare-metal already on the LAN = false)"
  type        = bool
  default     = true
}

variable "chef_server_url" {
  description = "URL of the chef/cinc server (e.g. https://cinc-server.munchbox.cc/organizations/munchbox)"
  type        = string
}

variable "chef_node_name" {
  description = "Node name to register with chef-server. Conventionally the hyphen-stripped hostname (e.g. 'oraclearm1' not 'oracle-arm-1') to match existing nomad node_name + role lookup"
  type        = string
}

variable "chef_validator_client_name" {
  description = "Validator client name for the org (e.g. 'munchbox-validator')"
  type        = string
}

# --- Validator key (per-org) is read at apply time via vault_kv_secret_v2. ---
variable "chef_validator_vault_mount" {
  description = "Vault KV v2 mount holding the chef validator key (default 'secret')"
  type        = string
  default     = "secret"
}

variable "chef_validator_vault_name" {
  description = "Vault KV v2 path (under mount) for the chef validator key, e.g. 'cinc/validator'"
  type        = string
  default     = "cinc/validator"
}

variable "chef_validator_vault_field" {
  description = "Field name in the validator KV entry that holds the PEM body"
  type        = string
  default     = "pem"
}

# --- Encrypted data-bag secret (shared across all chef-managed nodes). ---
variable "chef_data_bag_secret_vault_mount" {
  description = "Vault KV v2 mount holding the encrypted_data_bag_secret (default 'secret')"
  type        = string
  default     = "secret"
}

variable "chef_data_bag_secret_vault_name" {
  description = "Vault KV v2 path (under mount) for the encrypted_data_bag_secret, e.g. 'cinc/encrypted_data_bag_secret'"
  type        = string
  default     = "cinc/encrypted_data_bag_secret"
}

variable "chef_data_bag_secret_vault_field" {
  description = "Field name in the data-bag-secret KV entry that holds the raw secret"
  type        = string
  default     = "value"
}

variable "chef_run_list" {
  description = "First-run role entry, e.g. 'role[oracle_arm_5]'. The per-node role must already exist on chef-server"
  type        = string
}

variable "cinc_version" {
  description = "cinc-client version to install at bootstrap. Match what cinc_client cookbook pins"
  type        = string
  default     = "19.2.12"
}

# -----------------------------------------------------------------------------
# CHEF BOOTSTRAP -- static network (optional)
# -----------------------------------------------------------------------------

variable "static_ip" {
  description = "Static IP for the primary interface (e.g. '192.168.68.50'). Leave empty to keep DHCP"
  type        = string
  default     = ""
}

variable "static_netmask_bits" {
  description = "Netmask in CIDR-bits notation (e.g. 22 for a /22). Only used when static_ip is set"
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Default gateway IP. Only used when static_ip is set"
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "Initial DNS resolvers for the static-IP path (e.g. Pi-holes). consul::dns takes over after first chef converge"
  type        = list(string)
  default     = []
}

variable "network_interface" {
  description = "Primary network interface name for netplan (e.g. ens18 on proxmox, ens3 on oracle). Only used when static_ip is set"
  type        = string
  default     = "ens18"
}

# -----------------------------------------------------------------------------
# CHEF BOOTSTRAP -- /etc/hosts pins
# -----------------------------------------------------------------------------

variable "hosts_overrides" {
  description = "Map of hostname=>IP to pin in /etc/hosts before chef runs. Always include cinc-server.munchbox.cc since first-converge needs to reach it before consul::dns has been set up"
  type        = map(string)
  default = {
    "cinc-server.munchbox.cc" = "192.168.68.99"
  }
}

# -----------------------------------------------------------------------------
# MUNCHBOX PKI -- root + intermediate CA PEMs to trust on first converge
# -----------------------------------------------------------------------------
# Read by the env_helper from the chef cookbook's files/ dir so terragrunt
# doesn't have to reach across infrastructure/ trees from inside its cache.

variable "munchbox_root_ca" {
  description = "PEM-encoded Munchbox root CA cert. Loaded by the env_helper from infrastructure/cinc/cookbooks/munchbox_base/files/default/munchbox-root-ca.crt"
  type        = string
  sensitive   = false
}

variable "munchbox_intermediate_ca" {
  description = "PEM-encoded Munchbox intermediate CA cert. Loaded by the env_helper from infrastructure/cinc/cookbooks/munchbox_base/files/default/munchbox-intermediate-ca.crt"
  type        = string
  sensitive   = false
}
