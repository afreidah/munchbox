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
# ZFS ARC bounds
#
# zfs_arc_max (cap) + zfs_arc_min (floor) in bytes. Written to
# /etc/modprobe.d/zfs.conf AND applied live via
# /sys/module/zfs/parameters/zfs_arc_{max,min} so an unplanned reboot
# isn't required to take effect. The floor keeps ARC from collapsing
# under VM memory pressure on hosts that also serve cached storage.
# nil = no chef-managed bound for that field. min must stay <= max.
# -------------------------------------------------------------------------------

default[cookbook]['zfs_arc'] = {
  max_bytes: nil,
  min_bytes: nil,
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
  enabled: false,
  device_ids: [],
  modules: %w(vfio vfio_iommu_type1 vfio_pci),
}

# -------------------------------------------------------------------------------
# Kernel cmdline (GRUB_CMDLINE_LINUX_DEFAULT)
#
# Single owner of the boot cmdline. IOMMU params are added automatically
# when gvt_g/pci_passthrough are enabled; mitigations_off disables CPU
# vuln mitigations (perf vs security tradeoff -- old i5s only). Reboot to
# take effect is operator-gated.
# -------------------------------------------------------------------------------

default[cookbook]['kernel_cmdline'] = {
  base: ['quiet'],
  mitigations_off: false,
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
  enabled: false,
  bin_path: '/opt/zfswatcher/zfswatcher',
  config_path: '/etc/zfswatcher/zfswatcher.conf',
  log_dir: '/var/log/zfswatcher',
  bind: '0.0.0.0:8800',
  # --- nil by default; recipe lazy-fetches from Vault. Override to a literal for kitchen / break-glass. ---
  proxy_password_hash: nil,
}

# -------------------------------------------------------------------------------
# zfswatcher build-from-source
#
# rouben/zfswatcher isn't packaged anywhere we trust, so the cookbook
# builds it on-host from the pinned ref. First converge installs the go
# toolchain and clones; subsequent converges skip the build when the
# recorded commit matches the resolved ref. Bumping `ref` triggers a
# rebuild on the next converge.
#
# --- pre-modules GOPATH code: deps vendored under golibs/src, no go.mod ---
# --- so build with GO111MODULE=off + GOPATH=golibs, matching upstream Makefile ---
# -------------------------------------------------------------------------------

default[cookbook]['zfswatcher_build'] = {
  repo_url: 'https://github.com/rouben/zfswatcher.git',
  ref: 'master',
  install_dir: '/opt/zfswatcher',
  src_dir: '/opt/zfswatcher/src',
  build_cmd: 'GO111MODULE=off GOPATH="$(pwd)/golibs:$(go env GOPATH)" go build -o zfswatcher .',
}

default[cookbook]['vault_paths'] = {
  zfswatcher_proxy_password: {
    path: 'secret/data/proxmox/zfswatcher-proxy',
    field: 'password_hash',
  },
}

# -------------------------------------------------------------------------------
# Kernel sysctl tuning
#
# Map of sysctl name => value, applied persistently + live (no reboot).
# vm.swappiness drops from the distro default of 60 -- a hypervisor should
# shrink page cache long before paging out guest RAM.
# -------------------------------------------------------------------------------

default[cookbook]['sysctl'] = {
  'vm.swappiness' => 10,
}

# -------------------------------------------------------------------------------
# KSM (kernel samepage merging)
#
# Ensures ksmtuned runs so identical guest pages dedupe under memory
# pressure. Safe fleet-wide; ksmtuned self-activates only when needed.
# -------------------------------------------------------------------------------

default[cookbook]['ksm'] = {
  enabled: true,
}

# -------------------------------------------------------------------------------
# PVE no-subscription apt repo
#
# Owns /etc/apt/sources.list.d/pve-no-subscription.list with the codename
# tracking the host OS (read from /etc/os-release), correcting hosts left
# on a stale release after an OS upgrade.
# -------------------------------------------------------------------------------

default[cookbook]['apt_repo'] = {
  manage: true,
}
