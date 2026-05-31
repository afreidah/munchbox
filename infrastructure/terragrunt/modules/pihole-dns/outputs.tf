# -----------------------------------------------------------------------------
# PI-HOLE DNS MODULE - OUTPUTS
# -----------------------------------------------------------------------------

output "dns_records_primary" {
  description = "Created DNS A records on primary Pi-hole"
  value = {
    for k, v in pihole_local_dns.primary : k => {
      domain = v.hostname
      ip     = v.ip
    }
  }
}

output "dns_records_secondary" {
  description = "Created DNS A records on secondary Pi-hole"
  value = {
    for k, v in pihole_local_dns.secondary : k => {
      domain = v.hostname
      ip     = v.ip
    }
  }
}

output "cname_records_primary" {
  description = "Created CNAME records on primary Pi-hole"
  value = {
    for k, v in pihole_cname_record.primary : k => {
      domain = v.domain
      target = v.target
    }
  }
}

output "cname_records_secondary" {
  description = "Created CNAME records on secondary Pi-hole"
  value = {
    for k, v in pihole_cname_record.secondary : k => {
      domain = v.domain
      target = v.target
    }
  }
}
