# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Resource:: consul_dns
#
# Wires up local DNS routing so .consul queries reach the host's consul
# agent. Installs dnsmasq, drops a dnsmasq config that forwards .consul
# to consul:8600 and everything else to a local CoreDNS (with Pi-hole
# fallback if CoreDNS is down), disables systemd-resolved + avahi, and
# takes over /etc/resolv.conf to point at dnsmasq.
#
# Resolution flow when configured:
#   process -> dnsmasq (127.0.0.53)
#               -> .consul ........... consul (127.0.0.1:8600)
#               -> everything else ... CoreDNS (127.0.0.1:5354)
#                                       -> Pi-holes round-robin
#   (dnsmasq fails over directly to Pi-holes if CoreDNS is down)
#
# Properties:
#   host_ip                  - Secondary listen address so containers on
#                              the host's network can hit dnsmasq. REQUIRED.
#   listen_address           - Loopback listen address. Default 127.0.0.53.
#   consul_dns_port          - Local consul agent DNS port. Default 8600.
#   coredns_port             - Local CoreDNS port. Default 5354.
#   pihole_servers           - Direct fallback list when CoreDNS is down.
#   cache_size               - dnsmasq cache-size directive. Default 1000.
#   dns_forward_max          - dnsmasq dns-forward-max. Default 150.
#   dnsmasq_config_path      - Default /etc/dnsmasq.d/consul.conf.
#   resolv_conf_search       - search domain in /etc/resolv.conf.
#   disable_systemd_resolved - Default true (it binds port 53).
#   disable_avahi            - Default true (mDNS collides on 5353).
#   manage_resolv_conf       - Set false to leave /etc/resolv.conf alone.
#                              Default true.
# -------------------------------------------------------------------------------

unified_mode true

provides :consul_dns

property :host_ip,                  String, required: true
property :listen_address,           String,        default: '127.0.0.53'
property :consul_dns_port,          Integer,       default: 8600
property :coredns_port,             Integer,       default: 5354
property :pihole_servers,           Array,         default: %w(192.168.68.62 192.168.68.64)
property :cache_size,               Integer,       default: 1000
property :dns_forward_max,          Integer,       default: 150
property :dnsmasq_config_path,      String,        default: '/etc/dnsmasq.d/consul.conf'
property :resolv_conf_search,       String,        default: 'munchbox.cc'
property :disable_systemd_resolved, [true, false], default: true
property :disable_avahi,            [true, false], default: true
property :manage_resolv_conf,       [true, false], default: true
property :filter_aaaa,              [true, false], default: true

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Disable conflicts, install dnsmasq, drop config, take resolv.conf
# -------------------------------------------------------------------------------

action :configure do
  # --- Avahi binds port 5353 (mDNS); we don't use it. ---
  if new_resource.disable_avahi
    service 'avahi-daemon' do
      action %i(stop disable)
      ignore_failure true
    end
  end

  # --- dnsmasq depends on the apt cache from munchbox_base::apt_repo being current. ---
  munchbox_base_apt_lock_wait 'consul_dns_install'

  apt_package 'dnsmasq' do
    action :install
    notifies :restart, 'service[dnsmasq]', :delayed
  end

  # --- systemd-resolved owns port 53 by default; both can't bind. Stop it before dnsmasq starts. ---
  if new_resource.disable_systemd_resolved
    service 'systemd-resolved' do
      action %i(stop disable)
      ignore_failure true
    end
  end

  # --- Old fragment from the ansible play; remove if present so we don't double-config. ---
  file '/etc/dnsmasq.d/10-consul.conf' do
    action :delete
  end

  template new_resource.dnsmasq_config_path do
    source 'dnsmasq-consul.conf.erb'
    cookbook 'consul'
    owner 'root'
    group 'root'
    mode  '0644'
    variables(
      listen_address: new_resource.listen_address,
      host_ip: new_resource.host_ip,
      consul_dns_port: new_resource.consul_dns_port,
      coredns_port: new_resource.coredns_port,
      pihole_servers: new_resource.pihole_servers,
      cache_size: new_resource.cache_size,
      dns_forward_max: new_resource.dns_forward_max,
      filter_aaaa: new_resource.filter_aaaa
    )
    notifies :restart, 'service[dnsmasq]', :delayed
  end

  # --- /etc/resolv.conf takeover. Lists ONLY dnsmasq so libc/Go resolvers can't bypass
  # ---  the CoreDNS round-robin and hit Pi-holes directly (which would imbalance load).
  if new_resource.manage_resolv_conf
    template '/etc/resolv.conf' do
      source 'resolv.conf.erb'
      cookbook 'consul'
      owner 'root'
      group 'root'
      mode  '0644'
      variables(
        listen_address: new_resource.listen_address,
        search: new_resource.resolv_conf_search
      )
    end
  end

  service 'dnsmasq' do
    action %i(enable start)
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Stop dnsmasq, restore systemd-resolved, drop config + resolv.conf
# -------------------------------------------------------------------------------

action :remove do
  service 'dnsmasq' do
    action %i(stop disable)
    ignore_failure true
  end

  file new_resource.dnsmasq_config_path do
    action :delete
  end

  if new_resource.disable_systemd_resolved
    service 'systemd-resolved' do
      action %i(enable start)
      ignore_failure true
    end
  end
end
