# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Recipe:: ingress_prereqs
#
# Prepares an ingress host (currently nomad-client-05) for the
# wireguard-server nomad job: persists the wireguard kernel module load
# so the container can manage wg0 in the host netns, installs
# wireguard-tools on the host for operator `wg show` access, and removes
# the obsolete keepalived-vmac sysctl drop-in (the VRRP VIP no longer
# uses use_vmac).
# -------------------------------------------------------------------------------

cfg = node[cookbook]['ingress_prereqs']

wireguard_ingress_prereqs 'baseline' do
  module_load_path cfg['module_load_path']
  packages         cfg['packages']
  stale_sysctls    cfg['stale_sysctls']
end
