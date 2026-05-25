# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Attributes:: default
#
# Proxmox VE hypervisor knobs. Per-node roles set the per-host values
# (arc cap byte count, GPU mode, NFS exports). Cookbook defaults are
# safe no-ops -- nothing fires unless the per-node role opts in.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# ZFS ARC cap
#
# zfs_arc_max in bytes. Written to /etc/modprobe.d/zfs.conf AND applied
# live via /sys/module/zfs/parameters/zfs_arc_max so an unplanned reboot
# isn't required to take effect. nil = no chef-managed cap (preserve
# whatever modprobe defaults to).
# -------------------------------------------------------------------------------

default[cookbook]['zfs_arc'] = {
  max_bytes: nil,
}

# -------------------------------------------------------------------------------
# GPU enablement
#
# Two mutually-exclusive styles in this fleet:
#   gvt_g          - Intel iGPU mediated device split (fontana). Renders
#                    `intel_iommu=on i915.enable_gvt=1` into the grub
#                    cmdline and loads kvmgt/vfio-iommu-type1/vfio-mdev.
#   pci_passthrough - Full PCI device passthrough (rubirosa for nvidia).
#                    Renders `intel_iommu=on iommu=pt` into the grub
#                    cmdline, loads vfio/vfio_iommu_type1/vfio_pci, and
#                    drops /etc/modprobe.d/vfio.conf with the device IDs.
#
# Both require a reboot to take effect. Cookbook only enforces the
# on-disk state; it does NOT auto-reboot (shared infra, planned op).
# -------------------------------------------------------------------------------

default[cookbook]['gvt_g'] = {
  enabled: false,
  modules: %w(kvmgt vfio-iommu-type1 vfio-mdev),
}

default[cookbook]['pci_passthrough'] = {
  enabled:    false,
  device_ids: [],
  modules:    %w(vfio vfio_iommu_type1 vfio_pci),
}

# -------------------------------------------------------------------------------
# zfswatcher (rubirosa only today)
#
# Web UI on port 8800, routed through traefik at zfs.munchbox.cc. Proxy
# password is fetched from Vault (NEVER baked into the cookbook). Binary
# is expected at /opt/zfswatcher/zfswatcher; cookbook does not build it
# (rouben/zfswatcher needs golang + git + make to compile -- bootstrap
# is a one-time operator step, not a converge concern).
# -------------------------------------------------------------------------------

default[cookbook]['zfswatcher'] = {
  enabled:     false,
  bin_path:    '/opt/zfswatcher/zfswatcher',
  config_path: '/etc/zfswatcher/zfswatcher.conf',
  log_dir:     '/var/log/zfswatcher',
  bind:        '0.0.0.0:8800',
}

default[cookbook]['vault_paths'] = {
  zfswatcher_proxy_password: {
    path:  'secret/data/proxmox/zfswatcher-proxy',
    field: 'password_hash',
  },
}
