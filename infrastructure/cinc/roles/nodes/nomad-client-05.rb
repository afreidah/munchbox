# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad-client-05
#
# Per-node config for nomad-client-05 (192.168.68.74) -- a proxmox VM
# running as a nomad+consul client. Has wg1 to 10.201.0.3 (ansible-managed,
# not yet covered by chef).
# -------------------------------------------------------------------------------

name 'nomad-client-05'
description 'nomad-client-05: cluster nomad+consul client on a proxmox VM'

run_list(
  'role[proxmox_node]',
  # --- Ingress-side WG tunnel into the oracle wg1 mesh (10.200.0.0/24). Only the ingress proxmox node needs this. ---
  'recipe[wireguard::install]',
  'recipe[wireguard::configure]',
  # --- Host prep for the wireguard-server nomad job (kernel module loaded across reboots + wg-tools on the host + obsolete keepalived-vmac sysctl removed). ---
  'recipe[wireguard::ingress_prereqs]'
)

# --- consul-client + nomad-client cert defs. alt_names cover hostname + FQDN + the consul/nomad common-name forms; ip_sans = primary LAN IP + localhost. Matches what ansible's /etc/vault-cert-manager/config.yaml currently produces. ---
default_attributes(
  # --- Where local dnsmasq listens; consul::dns + docker::configure both read this so containers and the host resolve .consul via the local agent. ---
  global: {
    dns_endpoint_ip: '192.168.68.74',
  },
  consul: {
    config: {
      bind_addr: '192.168.68.74',
    },
  },
  nomad: {
    config: {
      node_name:    'nomad-client-05',
      advertise_ip: '192.168.68.74',
      # --- Required so the keepalived system job (constraint: meta.role=="ingress") lands here and its template can render `interface <eth>`. ---
      client_meta:  { 'role' => 'ingress', 'vrrp_interface' => 'eth0' },
    },
  },
  wireguard: {
    interfaces: {
      wg1: {
        address:     '10.201.0.3/32',
        mtu:         1380,
        vault_path:  'secret/data/wireguard-v2/nc05',
        vault_field: 'private_key',
        peers: [
          {
            'name'                 => 'oracle-node-1',
            'vault_path'           => 'secret/data/wireguard-v2/oracle-node-1',
            'vault_field'          => 'public_key',
            'allowed_ips'          => ['10.200.0.11/32'],
            'endpoint'             => '132.226.87.58:51820',
            'persistent_keepalive' => 25,
          },
          {
            'name'                 => 'oracle-node-2',
            'vault_path'           => 'secret/data/wireguard-v2/oracle-node-2',
            'vault_field'          => 'public_key',
            'allowed_ips'          => ['10.200.0.12/32'],
            'endpoint'             => '158.101.33.133:51820',
            'persistent_keepalive' => 25,
          },
          {
            'name'                 => 'oracle-arm-1',
            'vault_path'           => 'secret/data/wireguard-v2/oracle-arm-1',
            'vault_field'          => 'public_key',
            'allowed_ips'          => ['10.200.0.13/32'],
            'endpoint'             => '132.226.26.135:51820',
            'persistent_keepalive' => 25,
          },
          {
            'name'                 => 'oracle-arm-2',
            'vault_path'           => 'secret/data/wireguard-v2/oracle-arm-2',
            'vault_field'          => 'public_key',
            'allowed_ips'          => ['10.200.0.14/32'],
            'endpoint'             => '137.131.39.64:51820',
            'persistent_keepalive' => 25,
          },
        ],
      },
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
        alt_names:    %w(localhost nomad-client-05 nomad-client-05.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.74 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
      {
        name:         'nomad-client',
        role:         'nomad-client',
        common_name:  'client.global.nomad',
        certificate:  '/etc/nomad.d/tls/nomad.crt',
        key:          '/etc/nomad.d/tls/nomad.key',
        ttl:          '720h',
        alt_names:    %w(localhost nomad-client-05 nomad-client-05.munchbox.cc client.global.nomad),
        ip_sans:      %w(192.168.68.74 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.74:4646', timeout: '5s' },
      },
    ],
  }
)
