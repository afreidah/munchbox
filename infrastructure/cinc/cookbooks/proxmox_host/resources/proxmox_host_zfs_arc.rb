# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_zfs_arc
#
# Bounds ZFS ARC via /etc/modprobe.d/zfs.conf (max_bytes = cap,
# min_bytes = floor) and applies each live (sysfs write) so changes take
# effect without reboot. The floor stops ARC from collapsing under VM
# memory pressure on hosts that also serve cached storage (NFS/ZFS).
#
# Both nil = remove the chef-managed drop-in (no chef-managed bounds,
# kernel default). Set per-node since each proxmox host has a different
# RAM budget; min_bytes must stay <= max_bytes.
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_zfs_arc

property :max_bytes,      [Integer, nil]
property :min_bytes,      [Integer, nil]
property :modprobe_path,  String, default: '/etc/modprobe.d/zfs.conf'
property :sysfs_max_path, String, default: '/sys/module/zfs/parameters/zfs_arc_max'
property :sysfs_min_path, String, default: '/sys/module/zfs/parameters/zfs_arc_min'

default_action :configure

action :configure do
  if new_resource.max_bytes.nil? && new_resource.min_bytes.nil?
    file new_resource.modprobe_path do
      action :delete
    end
  else
    # --- one `options zfs` line carrying whichever bounds are set ---
    opts = []
    opts << "zfs_arc_max=#{new_resource.max_bytes}" unless new_resource.max_bytes.nil?
    opts << "zfs_arc_min=#{new_resource.min_bytes}" unless new_resource.min_bytes.nil?

    file new_resource.modprobe_path do
      owner   'root'
      group   'root'
      mode    '0644'
      content "options zfs #{opts.join(' ')}\n"
    end

    # --- Live so the values take effect without reboot. Each is gated by `not_if` reading sysfs so it only fires on actual drift (avoids the `file` resource's newline-diff trap). max first: the kernel rejects arc_min > arc_max. ---
    unless new_resource.max_bytes.nil?
      execute "live zfs_arc_max to #{new_resource.max_bytes}" do
        command "echo #{new_resource.max_bytes} > #{new_resource.sysfs_max_path}"
        only_if { ::File.exist?(new_resource.sysfs_max_path) }
        not_if  "test \"$(cat #{new_resource.sysfs_max_path})\" = \"#{new_resource.max_bytes}\""
      end
    end

    unless new_resource.min_bytes.nil?
      execute "live zfs_arc_min to #{new_resource.min_bytes}" do
        command "echo #{new_resource.min_bytes} > #{new_resource.sysfs_min_path}"
        only_if { ::File.exist?(new_resource.sysfs_min_path) }
        not_if  "test \"$(cat #{new_resource.sysfs_min_path})\" = \"#{new_resource.min_bytes}\""
      end
    end
  end
end
