# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Resource:: wireguard_install
#
# System-level setup: install packages, ensure /etc/wireguard exists,
# optionally flip on ip_forward.
#
# Properties:
#   packages   - Array of apt package names to install (required).
#   ip_forward - Set net.ipv4.ip_forward=1 via sysctl if true (default true).
# -------------------------------------------------------------------------------

unified_mode true

provides :wireguard_install

property :packages,   Array, required: true
property :ip_forward, [true, false], default: true

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Install packages + /etc/wireguard + sysctl
# -------------------------------------------------------------------------------

action :install do
  package new_resource.packages do
    action :install
  end

  directory '/etc/wireguard' do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  # --- chef's `sysctl` resource isn't idempotent on the reload step in this version; do it ourselves with notify ---
  if new_resource.ip_forward
    file '/etc/sysctl.d/99-wireguard-ip-forward.conf' do
      content "net.ipv4.ip_forward = 1\n"
      owner   'root'
      group   'root'
      mode    '0644'
      notifies :run, 'execute[wireguard sysctl reload]', :immediately
    end

    execute 'wireguard sysctl reload' do
      command 'sysctl --system'
      action  :nothing
    end
  end
end
