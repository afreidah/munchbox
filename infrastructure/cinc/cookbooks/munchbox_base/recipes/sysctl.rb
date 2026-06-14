# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: sysctl
#
# Drops a munchbox sysctl drop-in covering kernel knobs that apply to
# every node. Currently:
#   - vm.overcommit_memory=1 so Redis (and anything else doing big
#     fork()+COW) can BGSAVE under memory pressure without tripping the
#     kernel's strict-accounting refusal.
#   - net.ipv4.ip_nonlocal_bind=1 so the ingress dnsdist can bind the
#     floating keepalived DNS VIP on the standby node.
# -------------------------------------------------------------------------------

knobs = node[cookbook]['sysctl']

munchbox_base_sysctl 'baseline' do
  path     knobs['path']
  settings knobs['settings']
end
