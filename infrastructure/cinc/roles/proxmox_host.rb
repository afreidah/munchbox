# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: proxmox_host
#
# Proxmox VE HYPERVISORS (cabot, mccoy, fontana, rubirosa). NOT the
# proxmox-hosted VMs -- those are role[proxmox_vm].
#
# Universal baseline only. Per-host concerns (GPU enablement, NFS
# server exports, zfswatcher) live in the per-node role's run_list so
# nothing irrelevant is even loaded on hosts that don't need it.
# -------------------------------------------------------------------------------

name 'proxmox_host'
description 'Proxmox VE hypervisor; base + cinc_client + consul client + universal proxmox_host bits'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- AFTER vault_agent so /run/vault-agent/token exists when vault_fetch runs. ---
  'recipe[munchbox_base::sshd_ca]',
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_client]',
  # --- Every hypervisor has its own ARC cap (per-node attribute); recipe is a no-op when max_bytes is nil. ---
  'recipe[proxmox_host::zfs_arc]',
  # --- No-reboot host tuning: swap pressure, memory dedup, PVE repo codename. ---
  'recipe[proxmox_host::sysctl]',
  'recipe[proxmox_host::ksm]',
  'recipe[proxmox_host::apt_repo]',
  # --- Single owner of GRUB_CMDLINE_LINUX_DEFAULT (IOMMU params + mitigations). ---
  'recipe[proxmox_host::kernel_cmdline]'
)

default_attributes(
  consul: {
    config: {
      retry_join: ['192.168.68.60', '192.168.68.61', '192.168.68.58'],
    },
  }
)

# --- override_attributes for the vault_pki_trust knobs. The cookbook's attribute file sets `default[cookbook]['vault_pki_trust'] = { whole hash literal }`, which Chef stores as a single leaf at `vault_pki_trust` -- role default_attributes at the SAME precedence level can't deep-merge into a leaf assignment and silently no-op. Override precedence wins cleanly. ---
override_attributes(
  munchbox_base: {
    vault_pki_trust: {
      reload_docker: false,
      # --- Drop /opt/nomad/tls (hypervisors don't run nomad); keep system trust + ca-chain.crt ---
      destinations: [
        '/usr/local/share/ca-certificates/vault-pki-ca.crt',
        { 'path' => '/etc/consul.d/tls/ca-chain.crt', 'owner' => 'consul', 'group' => 'consul', 'mode' => '0644', 'chain' => true },
      ],
    },
  }
)
