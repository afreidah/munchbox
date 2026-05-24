# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
# Resource:: wireguard_ingress_prereqs
#
# Host-side prep for nodes that run the wireguard-server nomad job.
#
# Properties:
#   module_load_path - systemd-modules-load.service drop-in path. Default
#                      /etc/modules-load.d/wireguard.conf.
#   packages         - Host apt packages to install (default
#                      [wireguard-tools]; the wireguard kernel module
#                      itself ships with the linux-image package on debian
#                      12, no separate `wireguard` package needed for the
#                      container's host-netns use).
#   stale_sysctls    - Array of paths under /etc/sysctl.d/ to remove. Used
#                      to clean up the keepalived-vmac drop-in that
#                      stomped ARP across the Deco mesh and is no longer
#                      needed since the VIP dropped use_vmac.
# -------------------------------------------------------------------------------

unified_mode true

provides :wireguard_ingress_prereqs

property :module_load_path, String, default: '/etc/modules-load.d/wireguard.conf'
property :packages,         Array,  default: %w(wireguard-tools)
property :stale_sysctls,    Array,  default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  file new_resource.module_load_path do
    content "wireguard\n"
    owner   'root'
    group   'root'
    mode    '0644'
  end

  # --- modprobe is idempotent; lsmod guard keeps the converge silent on subsequent runs. ---
  execute 'modprobe wireguard' do
    command 'modprobe wireguard'
    not_if  'lsmod | grep -q "^wireguard "'
  end

  package new_resource.name do
    package_name new_resource.packages
    action       :install
  end

  # --- Sweep deprecated sysctl drop-ins; chef's file resource is a no-op when the path is absent. Notify the global reloader so any removed knob actually takes effect this converge. ---
  new_resource.stale_sysctls.each do |path|
    file path do
      action   :delete
      notifies :run, 'execute[wireguard ingress sysctl reload]', :immediately
    end
  end

  execute 'wireguard ingress sysctl reload' do
    command 'sysctl --system'
    action  :nothing
  end
end
