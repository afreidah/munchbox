# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: disable_ipv6_ra
#
# Drops a sysctl that ignores Router Advertisements and flushes any RA-
# derived routes the kernel already installed. The home LAN's Deco mesh
# router keeps emitting RAs with prefix ::/64 even with IPv6 "disabled"
# in its UI, which installs an on-link route covering the v4-mapped v6
# address space and steers process-local connect()s into local v6 wildcard
# listeners (notably traefik on the ingress).
# -------------------------------------------------------------------------------

ra = node[cookbook]['disable_ipv6_ra']

munchbox_base_disable_ipv6_ra 'baseline' do
  sysctl_path ra['sysctl_path']
end
