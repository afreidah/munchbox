# -------------------------------------------------------------------------------
#  Nomad Pack Defaults
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  Default configuration for all Nomad jobs deployed via nomad-pack. Override
#  these values in individual job HCL files as needed.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Job Defaults
# -----------------------------------------------------------------------

namespace       = "default"
priority        = 50
deployment_profile = "standard"
meta_profile    = "standard"

# -----------------------------------------------------------------------
# Restart Behavior Defaults
# -----------------------------------------------------------------------

restart_attempts = 3
restart_interval = "5m"
restart_delay    = "15s"
restart_mode     = "fail"

# -----------------------------------------------------------------------
# Reschedule Defaults
# -----------------------------------------------------------------------

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Resource & Network Defaults
# -----------------------------------------------------------------------

resource_tier  = "small"
network_preset = "bridge"
dns_servers    = ["192.168.68.62", "192.168.68.64"]
