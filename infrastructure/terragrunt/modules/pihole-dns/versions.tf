# -------------------------------------------------------------------------------
# PIHOLE-DNS Module Version Requirements
# -------------------------------------------------------------------------------

# --- standalone validate fails: pihole.primary + pihole.secondary aliases
#     need real provider configs which only the leaf supplies. configuration_aliases
#     declaration below lets the parent leaf wire its own configs in. ---

terraform {
  required_version = ">= 1.5"

  required_providers {
    pihole = {
      source                = "ryanwholey/pihole"
      version               = "~> 0.2"
      configuration_aliases = [pihole.primary, pihole.secondary]
    }
  }
}
