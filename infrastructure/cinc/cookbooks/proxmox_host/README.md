# proxmox_host

Proxmox VE hypervisor concerns: ZFS ARC cap, GPU enablement (Intel GVT-g mediated devices + full PCI passthrough for NVIDIA), and the zfswatcher daemon.

In production today on rubirosa (zfs_arc + pci_passthrough + zfswatcher), fontana (gvt_g), mccoy + cabot (zfs_arc).

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role. |
| `zfs_arc` | Caps ZFS ARC at `node['proxmox_host']['zfs_arc']['max_bytes']` via `/etc/modprobe.d/zfs.conf` + live sysfs write (no reboot needed). nil = remove the chef-managed drop-in. |
| `gvt_g` | Rewrites `GRUB_CMDLINE_LINUX_DEFAULT` for Intel iGPU mediated-device split; adds `kvmgt`/`vfio-iommu-type1`/`vfio-mdev` to /etc/modules. Reboot operator-gated. |
| `pci_passthrough` | Rewrites `GRUB_CMDLINE_LINUX_DEFAULT` for `intel_iommu=on iommu=pt`; adds `vfio` modules + writes `/etc/modprobe.d/vfio.conf` with the device IDs. Reboot operator-gated. |
| `zfswatcher` | Manages the zfswatcher daemon (config + systemd unit); binary expected pre-built at `bin_path`. Proxy password fetched from Vault. |

## Testing

```
make lint
make test
make kitchen      # zfs_arc suite only
```

### Why kitchen only covers `zfs_arc`

- **gvt_g / pci_passthrough**: rewrite GRUB cmdline + load kernel modules. End-to-end "GPU actually passed through" needs real hardware. The grub rewrite IS chefspec-tested.
- **zfswatcher**: needs ZFS pools + a pre-built `rouben/zfswatcher` binary at `/opt/zfswatcher/zfswatcher` (build is an operator one-time step, not a converge concern).

Real verification on hypervisors: bump attribute in the per-node role, push, `cinc-client`, then `cat /sys/module/zfs/parameters/zfs_arc_max` / `cat /proc/cmdline` / `systemctl status zfswatcher`.
