# -------------------------------------------------------------------------------
# cdktf-system-deny.hcl
# Prevent non-admins from touching the system namespace
# -------------------------------------------------------------------------------
namespace "system" { policy = "deny" }

