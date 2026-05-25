# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: fontana
#
# Proxmox hypervisor (192.168.68.65). Hands a slice of its Intel iGPU
# to nomad-client-01 via GVT-g (VM 180 has `hostpci0:
# 0000:00:02.0,mdev=i915-GVTg_V5_8`). No NFS server, no zfswatcher.
# -------------------------------------------------------------------------------

name 'fontana'
description 'fontana: proxmox VE hypervisor with Intel GVT-g (192.168.68.65)'

run_list(
  'role[proxmox_host]',
  'recipe[proxmox_host::gvt_g]'
)

default_attributes(
  consul: {
    config: {
      node_name: 'fontana',
      bind_addr: '192.168.68.65',
    },
  },
  proxmox_host: {
    # --- 1.55 GiB ARC cap matches current /etc/modprobe.d/zfs.conf. ---
    zfs_arc: { max_bytes: 1_666_187_264 },
    # --- GVT-g: cmdline + modules match live state. ---
    gvt_g:   { enabled: true },
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
        alt_names:    %w(localhost fontana fontana.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.65 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
    ],
  }
)
