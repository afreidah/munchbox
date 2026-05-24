# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: oracle_node
#
# Oracle Cloud free-tier nodes. Composes role[base] (OS baseline) +
# role[cinc_client] (chef-managed loop). WireGuard and other
# oracle-specific concerns come in later as their cookbooks land.
# -------------------------------------------------------------------------------

name 'oracle_node'
description 'Oracle Cloud free-tier node; runs base + cinc_client + vault_agent'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- SSH CA wiring; AFTER vault_agent so /run/vault-agent/token exists when vault_fetch runs. ---
  'recipe[munchbox_base::sshd_ca]',
  # --- Vault PKI intermediate CA -> /opt/nomad/tls + system trust. AFTER vault_agent, BEFORE docker::install so first install trusts the CA. ---
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_client]',
  'role[nomad_client]',
  'recipe[oracle::watchdog]',
  # --- Local dnsmasq -> consul/CoreDNS routing. Per-node roles must set global.dns_endpoint_ip to the node's wg1 IP. ---
  'recipe[consul::dns]',
  # --- docker daemon + daemon.json (DNS for containers points at the same wg1 host_ip). ---
  'recipe[docker::install]',
  'recipe[docker::configure]',
  # --- /etc/resolv.conf -> wg1 dns_endpoint_ip (not 127.0.0.53) so nomad's docker driver doesn't trip its systemd-resolved heuristic. ---
  'recipe[munchbox_base::resolv_conf]',
  # --- Tighter rsyslog rotation; all 4 oracle nodes have rsyslog installed and node-1/node-2 currently hold ~500MB syslog.1 files. ---
  'recipe[munchbox_base::rsyslog_rotation]',
  # --- containernetworking/plugins under /opt/cni/bin for nomad bridge networking + consul connect. ---
  'recipe[cni::install]'
)

# --- Shared per-fleet defaults for every oracle node: consul client joining the home cluster, nomad client pointed at the home servers with oracle-specific node_pool + WG interface for service registration. Per-node roles still need to set the *_name / bind_addr / advertise_ip values (those are per-node). ---
default_attributes(
  consul: {
    config: {
      retry_join: ['192.168.68.60', '192.168.68.61', '192.168.68.58'],
    },
  },
  nomad: {
    config: {
      servers:           ['192.168.68.60:4647', '192.168.68.61:4647', '192.168.68.58:4647'],
      node_pool:         'oracle',
      client_meta:       { 'cloud' => 'oracle' },
      network_interface: 'wg1',
    },
  },
  munchbox_base: {
    # --- SSH CA principals override; oracle nodes SSH as `ubuntu` so they need that principal in addition to root. ---
    ssh_ca: {
      principals: {
        'root' => ['root'],
        'ubuntu' => ['ubuntu'],
      },
    },
  }
)
