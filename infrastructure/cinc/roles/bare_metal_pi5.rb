# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: bare_metal_pi5
#
# The two bare-metal Raspberry Pi 5 nodes (goren + stabler, 192.168.68.60/61).
# These run consul+nomad in SERVER mode AND as clients (combined hosts), plus
# vault servers, the keepalived/traefik ingress VIP, patroni, haproxy, redis.
#
# Layering in from base; pieces get added one at a time. Per-node roles
# (goren.rb / stabler.rb) carry the identity overrides (node_name,
# bind_addr, advertise_ip).
# -------------------------------------------------------------------------------

name 'bare_metal_pi5'
description 'Bare-metal Pi5 server (goren/stabler)'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- ssh CA wiring; safe after vault_agent so vault_fetch has a token ---
  'recipe[munchbox_base::sshd_ca]',
  # --- vault PKI intermediate -> /opt/nomad/tls + system trust ---
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_server]',
  'role[nomad_server]',
  # --- gdrive NFS mounts from mccoy (same as proxmox clients). ---
  'recipe[nfs::client]'
)

default_attributes(
  # --- Shared nomad bits for combined server+client Pi5s. Per-node roles still set node_name + advertise_ip + server_join + vault_address + any node_class/client_meta. ---
  nomad: {
    config: {
      servers:   %w(192.168.68.61:4647 192.168.68.60:4647 192.168.68.58:4647),
      bind_addr: '0.0.0.0',
    },
  },
  # --- gdrive NFS mounts from mccoy (matches proxmox client fleet). ---
  nfs: {
    client: {
      mounts: [
        { mount_point: '/mnt/gdrive',           device: 'mccoy:/mnt/gdrive' },
        { mount_point: '/mnt/gdrive-secondary', device: 'mccoy:/mnt/gdrive-secondary' },
      ],
    },
  }
)

override_attributes(
  # --- chrony runs here; timesyncd removed ---
  munchbox_base: {
    timesync: { enabled: false },
  },
  # --- vault server already runs here; agent uses separate dir + existing binary ---
  vault_agent: {
    binary_path: '/usr/local/bin/vault',
    config_dir:  '/etc/vault-agent.d',
    install:     { install_binary: false, mask_vault_service: false },
  },
  # --- shared across both Pi5s (and would extend to nomad-server-03 once chef-managed). Per-node roles still set bind_addr. ---
  consul: {
    config: {
      retry_join: %w(192.168.68.61 192.168.68.60 192.168.68.58),
    },
  },
  # --- Combined server+client host. Must be override (not default) because role[nomad_server]'s default for client_enabled: false is applied LAST in role expansion order, beating any per-node default. ---
  nomad: {
    config: {
      client_enabled: true,
    },
  }
)
