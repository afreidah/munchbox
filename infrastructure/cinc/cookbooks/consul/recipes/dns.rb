# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Recipe:: dns
#
# Local-resolver setup: dnsmasq forwards .consul to the local consul
# agent and everything else through CoreDNS (Pi-hole fallback). Opt-in --
# not included in the default run_list; add to roles that want it
# (typically anything also running role[consul_client] + CoreDNS as a
# nomad system job).
#
# DNS endpoint IP resolution (in order):
#   1. consul.dns.host_ip       -- explicit override in the role
#   2. node['global']['dns_endpoint_ip'] -- per-node role-set shared value
#                                          (preferred -- shared with docker etc.)
#   3. node['ipaddress']        -- chef's autodetected primary IP (last resort)
#
# Requires: munchbox_base::apt_repo earlier in the run_list (for the apt
# cache) and the host already running a consul agent.
# -------------------------------------------------------------------------------

dns = node[cookbook]['dns']

# --- Derive at recipe time (per chef-style-guide: no derived attrs in attribute files). ---
host_ip = dns['host_ip'] ||
          (node['global'] && node['global']['dns_endpoint_ip']) ||
          node['ipaddress']

consul_dns 'baseline' do
  host_ip                  host_ip
  listen_address           dns['listen_address']
  consul_dns_port          dns['consul_dns_port']
  coredns_port             dns['coredns_port']
  pihole_servers           dns['pihole_servers']
  cache_size               dns['cache_size']
  dns_forward_max          dns['dns_forward_max']
  dnsmasq_config_path      dns['dnsmasq_config_path']
  resolv_conf_search       dns['resolv_conf_search']
  disable_systemd_resolved dns['disable_systemd_resolved']
  disable_avahi            dns['disable_avahi']
  manage_resolv_conf       dns['manage_resolv_conf']
  filter_aaaa              dns['filter_aaaa']
end
