# -------------------------------------------------------------------------------
# admin.hcl
# Full admin control via client token (avoid using management tokens day-to-day)
# -------------------------------------------------------------------------------
namespace "*" { policy = "write" }      # submit/scale/exec/logs/etc.
node         { policy = "write" }       # drain/cordon
agent        { policy = "write" }       # agent maintenance
operator     { policy = "write" }       # cluster ops
quota        { policy = "write" }
plugin       { policy = "write" }
host_volume "*" { policy = "write" }    # if you use host volumes
