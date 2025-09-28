# cdktf/munchbox-core/variables.hcl
# Common cluster configuration variables
# Load with: terraform apply -var-file="variables.hcl"
# Or set TF_VAR_* environment variables

variable "datacenter" {
  description = "Nomad datacenter name"
  type        = string
  default     = "pi-dc"
}

variable "domain" {
  description = "Internal domain suffix"
  type        = string  
  default     = "munchbox"
}

variable "public_domain" {
  description = "Public domain"
  type        = string
  default     = "alexfreidah.com"
}

variable "timezone" {
  description = "Cluster timezone"
  type        = string
  default     = "America/Los_Angeles"
}

variable "network_cidr" {
  description = "Internal network CIDR"
  type        = string
  default     = "192.168.68.0/24"
}

variable "consul_servers" {
  description = "List of Consul server endpoints"
  type        = list(string)
  default     = [
    "192.168.68.60:8500",
    "192.168.68.61:8500", 
    "192.168.68.63:8500"
  ]
}

variable "nomad_servers" {
  description = "List of Nomad server endpoints"
  type        = list(string)
  default     = [
    "192.168.68.60:4646",
    "192.168.68.61:4646",
    "192.168.68.63:4646"
  ]
}

# Node IP mappings for service backends
variable "node_ips" {
  description = "Node IP address mappings"
  type        = map(string)
  default     = {
    goren   = "192.168.68.60"
    stabler = "192.168.68.61" 
    green   = "192.168.68.62"
    mccoy   = "192.168.68.63"
    cabot   = "192.168.68.59"
    logan   = "192.168.68.64"
  }
}

# Common resource limits
variable "resource_profiles" {
  description = "Standard resource allocation profiles"
  type        = map(object({
    cpu    = number
    memory = number
  }))
  default = {
    micro = {
      cpu    = 50
      memory = 64
    }
    small = {
      cpu    = 100
      memory = 128
    }
    medium = {
      cpu    = 250
      memory = 512
    }
    large = {
      cpu    = 1000
      memory = 2048
    }
  }
}

# Common restart policies
variable "restart_policies" {
  description = "Standard restart policy configurations"
  type        = map(object({
    attempts = number
    interval = string
    delay    = string
    mode     = string
  }))
  default = {
    standard = {
      attempts = 5
      interval = "10m"
      delay    = "5s"
      mode     = "delay"
    }
    critical = {
      attempts = 10
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }
    batch = {
      attempts = 0
      interval = "10m"
      delay    = "5s"
      mode     = "fail"
    }
  }
}
