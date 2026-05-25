# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: rubirosa
#
# Proxmox hypervisor (192.168.68.69). Hands an NVIDIA RTX A1000 GPU
# (10de:25b0) + its companion HDMI audio device (10de:2291) to
# nomad-client-04 (VM 183) via full PCI passthrough -- nomad-client-04
# is the media-stack node that needs hardware transcoding.
#
# Also serves NFS exports of its /tank dataset to the LAN, and runs
# zfswatcher (the web UI behind https://zfs.munchbox.cc/, routed
# through traefik with oauth2-proxy in front).
#
# Doesn't have consul installed pre-takeover (the only proxmox host
# without it) -- chef will install it first time, hitting vault for
# the agent token.
# -------------------------------------------------------------------------------

name 'rubirosa'
description 'rubirosa: proxmox VE hypervisor + NVIDIA passthrough + /tank NFS + zfswatcher (192.168.68.69)'

run_list(
  'role[proxmox_host]',
  'recipe[proxmox_host::pci_passthrough]',
  'recipe[proxmox_host::zfswatcher]',
  'recipe[nfs::server]'
)

default_attributes(
  consul: {
    config: {
      node_name: 'rubirosa',
      bind_addr: '192.168.68.69',
    },
  },
  proxmox_host: {
    # --- 32 GiB ARC cap on rubirosa's larger zpool; matches current /etc/modprobe.d/zfs.conf. ---
    zfs_arc: { max_bytes: 34_359_738_368 },
    # --- NVIDIA RTX A1000 + HDMI audio bound to vfio-pci so nomad-client-04 can claim them. cmdline + modules match live state. ---
    pci_passthrough: {
      enabled:    true,
      device_ids: %w(10de:25b0 10de:2291),
    },
    # --- zfswatcher daemon owns https://zfs.munchbox.cc/; binary is built once from rouben/zfswatcher source (not auto-built by chef). ---
    zfswatcher: { enabled: true },
  },
  nfs: {
    server: {
      exports: [
        { 'path' => '/tank', 'clients' => '192.168.68.0/24', 'options' => 'rw,sync,no_subtree_check,no_root_squash' },
      ],
    },
  },
  vault_cert_manager: {
    certificates: [
      {
        name:         'consul-client',
        role:         'consul-client',
        common_name:  'client.munchbox.consul',
        certificate:  '/etc/consul.d/tls/consul.crt',
        key:          '/etc/consul.d/tls/consul.key',
        ttl:          '720h',
        alt_names:    %w(localhost rubirosa rubirosa.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.69 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
    ],
  }
)
