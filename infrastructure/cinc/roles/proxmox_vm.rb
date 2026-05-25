# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: proxmox_vm
#
# Proxmox-hosted VMs (nomad-client-01..05). NOT the hypervisors themselves
# -- those are role[proxmox_host] (cabot/fontana/mccoy/rubirosa).
# -------------------------------------------------------------------------------

name 'proxmox_vm'
description 'Proxmox-hosted nomad-client VM; runs base + cinc_client'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- SSH CA wiring; AFTER vault_agent so /run/vault-agent/token exists when vault_fetch runs. Default principal (root => ['root']) is correct since these nodes SSH as root. ---
  'recipe[munchbox_base::sshd_ca]',
  # --- Vault PKI intermediate CA -> /opt/nomad/tls + system trust. AFTER vault_agent, BEFORE docker::install so first install trusts the CA. ---
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_client]',
  # --- Local dnsmasq -> consul/CoreDNS routing. Reads global.dns_endpoint_ip per-node. ---
  'recipe[consul::dns]',
  'recipe[docker::install]',
  'recipe[docker::configure]',
  # --- /etc/resolv.conf -> bind_addr (not 127.0.0.53) so nomad's docker driver doesn't trip its systemd-resolved heuristic. ---
  'recipe[munchbox_base::resolv_conf]',
  'role[nomad_client]',
  # --- Static route 10.200.0.0/24 via the keepalived WG VIP so proxmox clients can reach oracle WG peers. On nomad-client-05 (has its own wg1) the more-specific /32 wg1 routes win; this is a harmless fallback. ---
  'recipe[wireguard::route]',
  # --- containernetworking/plugins under /opt/cni/bin for nomad bridge networking + consul connect. ---
  'recipe[cni::install]',
  # --- Mount the gdrive NFS exports from mccoy (2TB external drive made network-accessible). ---
  'recipe[nfs::client]'
)

# --- Shared per-fleet defaults for every proxmox-hosted VM. Per-node roles must set consul.config.bind_addr + nomad.config.{node_name,advertise_ip}. ---
default_attributes(
  consul: {
    config: {
      retry_join: ['192.168.68.60', '192.168.68.61', '192.168.68.58'],
    },
  },
  nomad: {
    config: {
      servers:   ['192.168.68.60:4647', '192.168.68.61:4647', '192.168.68.58:4647'],
      bind_addr: '0.0.0.0',
    },
  },
  nfs: {
    client: {
      package: 'nfs-common',
      mounts: [
        { mount_point: '/mnt/gdrive',           device: 'mccoy:/mnt/gdrive' },
        { mount_point: '/mnt/gdrive-secondary', device: 'mccoy:/mnt/gdrive-secondary' },
      ],
    },
  }
)
