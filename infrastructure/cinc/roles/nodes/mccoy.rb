# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: mccoy
#
# Proxmox hypervisor (192.168.68.63). NFS server for the fleet's
# /mnt/gdrive + /mnt/gdrive-secondary exports (2TB external drive made
# network-accessible). No GPU passthrough, no zfswatcher.
#
# NFS server has the largest blast radius on the cluster -- every
# proxmox-hosted VM and bare-metal node mounts these exports. Roll
# mccoy LAST, after cabot/fontana/rubirosa prove out.
# -------------------------------------------------------------------------------

name 'mccoy'
description 'mccoy: proxmox VE hypervisor + NFS server for gdrive exports (192.168.68.63)'

run_list(
  'role[proxmox_host]',
  'recipe[nfs::server]'
)

default_attributes(
  consul: {
    config: {
      node_name: 'mccoy',
      bind_addr: '192.168.68.63',
    },
  },
  proxmox_host: {
    # --- 1.55 GiB ARC cap matches current /etc/modprobe.d/zfs.conf. ---
    zfs_arc: { max_bytes: 1_665_138_688 },
  },
  nfs: {
    server: {
      exports: [
        { 'path' => '/mnt/gdrive',           'clients' => '192.168.68.0/22', 'options' => 'rw,sync,no_subtree_check,no_root_squash' },
        { 'path' => '/mnt/gdrive-secondary', 'clients' => '192.168.68.0/22', 'options' => 'rw,sync,no_subtree_check,no_root_squash' },
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
        alt_names:    %w(localhost mccoy mccoy.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.63 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
    ],
  }
)
