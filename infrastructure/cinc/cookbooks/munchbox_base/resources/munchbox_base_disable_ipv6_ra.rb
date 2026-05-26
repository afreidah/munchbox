# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_disable_ipv6_ra
#
# Persistently disables IPv6 Router Advertisement processing on every
# interface and clears RA-derived routes already in the kernel.
#
# Properties:
#   sysctl_path - Path of the sysctl drop-in file. Default
#                 /etc/sysctl.d/99-disable-ipv6-ra.conf.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_disable_ipv6_ra

property :sysctl_path, String, default: '/etc/sysctl.d/99-disable-ipv6-ra.conf'

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  # --- Per-iface lines are required: the kernel ORs all.accept_ra with <iface>.accept_ra, so all=0 alone leaves RA-accepting interfaces unaffected. Enumerate live ifaces but skip container/virtual ones (veth*, br-*, cni*, lo): they churn with container lifecycle and would force a sysctl rewrite every converge. New stable interfaces created later (rare) inherit default=0. ---
  iface_skip = /\A(lo|all|default|veth|br-|cni)/
  ifaces     = ::Dir['/proc/sys/net/ipv6/conf/*'].map { |p| ::File.basename(p) }
                                                 .reject { |i| i =~ iface_skip }
                                                 .sort

  body  = ['# Managed by chef (munchbox_base::disable_ipv6_ra) -- do not edit by hand.']
  body << 'net.ipv6.conf.all.accept_ra = 0'
  body << 'net.ipv6.conf.default.accept_ra = 0'
  ifaces.each { |i| body << "net.ipv6.conf.#{i}.accept_ra = 0" }

  file new_resource.sysctl_path do
    content body.join("\n") + "\n"
    owner    'root'
    group    'root'
    mode     '0644'
    notifies :run, 'execute[reload sysctl ipv6 accept_ra]', :immediately
  end

  execute 'reload sysctl ipv6 accept_ra' do
    command "sysctl -p #{new_resource.sysctl_path}"
    action  :nothing
  end

  # --- Strip RA-derived routes installed before the sysctl took effect. Guarded so the converge stays idempotent once the routes are gone. ---
  execute 'flush ipv6 RA routes' do
    command 'ip -6 route flush proto ra'
    only_if 'ip -6 route show proto ra | grep -q .'
  end
end
