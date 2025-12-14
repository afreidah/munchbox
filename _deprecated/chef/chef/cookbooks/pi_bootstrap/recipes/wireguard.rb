# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - WireGuard Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs WireGuard for split-tunnel VPN via policy routing. Creates vpnmark
# user, generates keypair, and marks only vpnmark traffic through the VPN.
# -------------------------------------------------------------------------------

# --- Packages ----------------------------------------------------------------
package %w(wireguard wireguard-tools iproute2) do
  action :install
end

package 'procps' do
  action :install
end

package %w(iptables) do
  action :install
end

user 'vpnmark' do
  system true
  shell '/usr/sbin/nologin'
  home '/nonexistent'
  manage_home false
  uid 1001
end

# --- sysctl -p expects /etc/sysctl.conf; create a harmless stub --------------
file '/etc/sysctl.conf' do
  content "# managed by Chef — see /etc/sysctl.d/*.conf for actual settings\n"
  owner 'root'
  group 'root'
  mode  '0644'
  action :create_if_missing
end

# --- Service user whose traffic will egress via VPN ---------------------------
user 'vpnmark' do
  system true
  shell  '/usr/sbin/nologin'
  home   '/nonexistent'
end

# --- Load data bag: pia_vpn/wg ------------------------------------------------
pia_item = begin
  data_bag_item('pia_vpn', 'wg')
rescue => e
  Chef::Log.fatal("Missing data bag item pia_vpn/wg: #{e}")
  raise
end

# --- Prefer structured 'wireguard' block; gracefully map flat keys -----------
wg_cfg  = pia_item['wireguard'] || {}

# From 'wireguard' block (preferred if present)
srv_ip   = wg_cfg['server_ip']
srv_pk   = wg_cfg['server_pubkey']          # base64 server public key (PEER)
srv_prt  = wg_cfg['server_port']
addr     = wg_cfg['peer_address_cidr']      # e.g., "10.7.142.96/32"
allowed  = Array(wg_cfg['allowed_ips']).compact

# Back-compat: map your flat keys when the block is absent/incomplete
srv_ip ||= pia_item['wg_server_ip']
srv_prt ||= (pia_item['wg_port'] || 1337)

# --- Optional auto-discovery from an existing /etc/wireguard/pia.conf --------
conf_path = '/etc/wireguard/pia.conf'
if ::File.exist?(conf_path)
  conf = ::File.read(conf_path)

  addr   ||= (conf[/^Address\s*=\s*([^\s]+)/, 1])
  srv_pk ||= (conf[/^\[Peer\][\s\S]*?^PublicKey\s*=\s*([^\s]+)/m, 1])

  if srv_ip.to_s.empty? || srv_prt.to_s.empty?
    if (ep = conf[/^Endpoint\s*=\s*([^\s]+)/, 1])
      ep_ip, ep_port = ep.split(':', 2)
      srv_ip  ||= ep_ip
      srv_prt ||= (ep_port.to_i.nonzero? || 1337)
    end
  end
end

# Defaults for allowed_ips if not provided
allowed = ['0.0.0.0/0', '::/0'] if allowed.empty?

# --- Guardrails ---------------------------------------------------------------
raise 'wireguard.peer_address_cidr (peer tunnel address) is required' if addr.to_s.empty?
raise 'wireguard.server_ip is required'                                  if srv_ip.to_s.empty?
raise 'wireguard.server_pubkey is required (peer PublicKey from PIA)'    if srv_pk.to_s.empty?
srv_prt = 1337 if srv_prt.to_s.empty?

# --- WireGuard directory & keys ----------------------------------------------
directory '/etc/wireguard' do
  owner 'root'
  group 'root'
  mode  '0700'
end

execute 'wg-generate-private-key' do
  command 'umask 077 && wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key'
  creates '/etc/wireguard/private.key'
end

file '/etc/wireguard/private.key' do
  owner 'root'
  group 'root'
  mode  '0600'
  sensitive true
end

file '/etc/wireguard/public.key' do
  owner 'root'
  group 'root'
  mode  '0644'
end

# --- Kernel: allow policy routing with marks ---------------------------------
#     Required so replies are accepted when using socket/packet marks.
sysctl 'net.ipv4.conf.all.src_valid_mark' do
  value 1
end

# --- pia.conf (split-tunnel with policy routing) ------------------------------
template '/etc/wireguard/pia.conf' do
  source 'wg0.conf.erb'
  owner  'root'
  group  'root'
  mode   '0600'
  sensitive true
  variables(
    interface_address: addr,                        # "10.x.x.x/32"
    server_pubkey:     srv_pk,                      # base64 PIA peer pubkey
    server_endpoint:   "#{srv_ip}:#{srv_prt}",      # "<ip>:<port>"
    allowed_ips:       allowed,                     # keep broad; policy routing constrains actual use
    mark_hex:          '0x1',                       # packet mark used for split
    wg_table:          51820,                       # policy routing table id (arbitrary, stable)
    server_ip:         srv_ip                       # for endpoint host-route pinning
  )
end

# --- Systemd service for PIA WireGuard/Port Forwarding -------------------------
env_vars = [
  "PIA_TOKEN=#{pia_item['pia_token'] || pia_item['pia_user']}",
  "WG_SERVER_IP=#{srv_ip}",
  "PIA_PF=true"
]
env_vars << "WG_HOSTNAME=#{pia_item['wg_hostname']}" if pia_item['wg_hostname'] && !pia_item['wg_hostname'].empty?

systemd_unit 'pia-portforward.service' do
  content({
    Unit: {
      Description: 'PIA WireGuard Port Forwarding',
      After: 'network-online.target',
      Wants: 'network-online.target'
    },
    Service: {
      Type: 'simple',
      WorkingDirectory: '/opt/piavpn-manual',
      Environment: env_vars,
      ExecStart: '/opt/piavpn-manual/connect_to_wireguard_with_token.sh',
      Restart: 'always',
      RestartSec: 10
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  })
  action [:create, :enable, :start]
end

# --- Optional: Separate systemd service for PIA Port Forwarding ---------------
systemd_unit 'pia-portforward-refresh.service' do
  content({
    Unit: {
      Description: 'PIA Port Forwarding Refresh',
      After: 'network-online.target',
      Wants: 'network-online.target'
    },
    Service: {
      Type: 'simple',
      WorkingDirectory: '/opt/piavpn-manual',
      Environment: [
        "PIA_TOKEN=#{pia_item['pia_token'] || pia_item['pia_user']}",
        "PF_GATEWAY=#{srv_ip}",
        "PF_HOSTNAME=#{pia_item['wg_hostname']}"
      ],
      ExecStart: '/opt/piavpn-manual/port_forwarding.sh',
      Restart: 'always',
      RestartSec: 10
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  })
  action [:create, :enable, :start]
end
