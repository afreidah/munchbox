# -----------------------------------------------------------------------------
# PI-HOLE DNS MODULE - VARIABLES
# -----------------------------------------------------------------------------

variable "dns_records" {
  description = "Map of DNS A records to create"
  type = map(object({
    domain = string
    ip     = string
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create"
  type = map(object({
    domain = string
    target = string
  }))
  default = {}
}
