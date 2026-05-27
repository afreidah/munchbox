# -------------------------------------------------------------------------------
# PIHOLE-DNS Module Version Requirements
# -------------------------------------------------------------------------------

# --- standalone validate fails: pihole.primary + pihole.secondary aliases
#     need real provider configs which only the leaf supplies. configuration_aliases
#     declaration below lets the parent leaf wire its own configs in. ---

terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 2.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.12"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.1"
    }
    pihole = {
      source                = "ryanwholey/pihole"
      version               = "~> 0.2"
      configuration_aliases = [pihole.primary, pihole.secondary]
    }
  }
}
