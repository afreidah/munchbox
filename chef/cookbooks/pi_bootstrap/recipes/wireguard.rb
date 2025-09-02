# ---------------------------------------------------------------------------
#  Cookbook:: pi_bootstrap
#  Recipe:: wireguard_split
#
#  Purpose:
#    - Install WireGuard packages
#    - Create dedicated service user (vpnmark)
#    - Generate wg keypair if missing
#    - Render /etc/wireguard/wg0.conf for SPLIT-TUNNEL via policy routing
#    - Mark only vpnmark traffic (fwmark 0x1) and route via table 51820
#    - Enable/start wg-quick@wg0
#
#  Notes:
#    - We DO NOT hijack the default route. Only MARKED traffic uses table 51820.
#    - DNS left alone (no DNS= in wg0.conf).
#    - All routing glue (ip rule / table 51820 / endpoint host-route / marks)
#      lives in PostUp/PreDown so it stays coupled to interface state.
#
#  Data bag (YOU HAVE TODAY):
#    bag:  pia_vpn
#    item: wg
#    body:
#      {
#        "id": "wg",
#        "pia_user": "p0673666",
#        "pia_pass": "j*#37w$ttMGv+q3",
#        "preferred_region": "greenland",
#        "wg_hostname": "greenland403",
#        "wg_server_ip": "91.90.120.137",
#        "wg_port": 1337,
#        "wireguard": {                 # <-- OPTIONAL (preferred if present)
#          "server_ip": "91.90.120.137",
#          "server_pubkey": "BASE64_PIA_SERVER_PUBKEY",
#          "server_port": 1337,
#          "peer_address_cidr": "10.7.142.96/32",
#          "allowed_ips": ["0.0.0.0/0"]
#        }
#      }
#
#  Validation:
#    - wg show
#    - curl ifconfig.me                         # normal user -> ISP egress
#    - sudo -u vpnmark curl ifconfig.me         # vpnmark user -> PIA egress
# ---------------------------------------------------------------------------

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
  notifies :restart, 'service[wg-quick@pia]', :delayed
end

# --- Service management -------------------------------------------------------
service 'wg-quick@pia' do
  action [:enable, :start]
end
