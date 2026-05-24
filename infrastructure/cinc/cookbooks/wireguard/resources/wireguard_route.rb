# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Resource:: wireguard_route
#
# Renders a oneshot systemd unit (`wireguard-route.service`) that adds a
# static route to a remote WG network via a gateway IP, and applies the
# route immediately so the host doesn't have to wait for a reboot to see
# it. Also cleans up legacy ifupdown-style files that the previous
# ansible play left behind.
#
# Properties:
#   network      - Destination CIDR (e.g. "10.200.0.0/24") (required).
#   gateway      - Next-hop IP (typically the keepalived VIP) (required).
#   service_name - systemd unit name (default 'wireguard-route').
#   legacy_paths - Array of file paths to remove on every converge (the
#                  old ansible-managed files that conflict with this one).
# -------------------------------------------------------------------------------

unified_mode true

provides :wireguard_route

property :network,      String, required: true
property :gateway,      String, required: true
property :service_name, String, default: 'wireguard-route'
property :legacy_paths, Array,  default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Render unit, enable + start, ensure route is live
# -------------------------------------------------------------------------------

action :configure do
  new_resource.legacy_paths.each do |path|
    file path do
      action :delete
    end
  end

  systemd_unit "#{new_resource.service_name}.service" do
    content <<~UNIT
      # Managed by chef (wireguard::route) -- do not edit by hand.
      [Unit]
      Description=Add route to WireGuard network #{new_resource.network}
      After=network-online.target
      Wants=network-online.target

      [Service]
      Type=oneshot
      # `replace` is idempotent: adds if missing, swaps gateway if present.
      # Using `add` here breaks when the prior unit set the route via a
      # different gateway (e.g. when the keepalived VIP holder changes).
      ExecStart=/sbin/ip route replace #{new_resource.network} via #{new_resource.gateway}
      ExecStop=-/sbin/ip route del #{new_resource.network} via #{new_resource.gateway}
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
    UNIT
    action %i(create enable start)
  end
end
