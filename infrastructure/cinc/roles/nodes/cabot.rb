# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: cabot
#
# Proxmox hypervisor (192.168.68.59). x86_64 mini PC. No GPU passthrough,
# no NFS server, no zfswatcher -- cleanest pilot for the proxmox_host
# takeover.
# -------------------------------------------------------------------------------

name 'cabot'
description 'cabot: proxmox VE hypervisor (192.168.68.59)'

run_list(
  'role[proxmox_host]'
)

default_attributes(
  consul: {
    config: {
      node_name: 'cabot',
      bind_addr: '192.168.68.59',
    },
  },
  proxmox_host: {
    # --- 785 MiB ARC cap matches current /etc/modprobe.d/zfs.conf on the node; preserved on takeover. ---
    zfs_arc: { max_bytes: 823_132_160 },
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
        alt_names:    %w(localhost cabot cabot.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.59 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
    ],
  }
)
