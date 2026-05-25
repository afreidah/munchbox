# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_zfs_arc
#
# Caps ZFS ARC at max_bytes via /etc/modprobe.d/zfs.conf, applies the
# new cap live (sysfs write) so the change takes effect without reboot.
#
# nil max_bytes = remove the chef-managed drop-in (no ARC limit, kernel
# default). Set per-node since each proxmox host has different RAM budgets.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_zfs_arc

property :max_bytes,     [Integer, nil]
property :modprobe_path, String, default: '/etc/modprobe.d/zfs.conf'
property :sysfs_path,    String, default: '/sys/module/zfs/parameters/zfs_arc_max'

default_action :configure

action :configure do
  if new_resource.max_bytes.nil?
    file new_resource.modprobe_path do
      action :delete
    end
  else
    file new_resource.modprobe_path do
      owner   'root'
      group   'root'
      mode    '0644'
      content "options zfs zfs_arc_max=#{new_resource.max_bytes}\n"
    end

    # --- Live cap so the new value takes effect without reboot. Gated by `not_if` reading sysfs so it only fires on actual drift (avoids the `file` resource's newline-diff trap). ---
    execute "live-cap zfs_arc_max to #{new_resource.max_bytes}" do
      command "echo #{new_resource.max_bytes} > #{new_resource.sysfs_path}"
      only_if { ::File.exist?(new_resource.sysfs_path) }
      not_if  "test \"$(cat #{new_resource.sysfs_path})\" = \"#{new_resource.max_bytes}\""
    end
  end
end
