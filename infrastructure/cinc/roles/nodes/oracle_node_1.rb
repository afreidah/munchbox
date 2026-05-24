# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: oracle_node_1
#
# Per-node role for oracle-node-1 (chef node name: oraclenode1). Same shape
# as oracle_arm_1/2; differs only in the wg1 interface address and the
# Vault path holding this node's private key. Peers + iptables rules are
# identical -- all four Oracle nodes are siblings behind the same goren
# ingress.
# -------------------------------------------------------------------------------

name 'oracle_node_1'
description 'oracle-node-1 specific config (composes oracle_node + wireguard wg1)'

run_list(
  'role[oracle_node]',
  'recipe[wireguard::install]',
  'recipe[wireguard::configure]'
)

default_attributes(
  # --- Shared host DNS endpoint IP. consul::dns binds dnsmasq here; docker::configure points containers here. Set once per node; both cookbooks read it from node['global']. ---
  global: {
    dns_endpoint_ip: '10.200.0.11',
  },
  consul: {
    config: {
      # --- Match the existing catalog entry (ansible inventory hostname). Changing this would re-register the agent under a new identity and orphan its scrape configs / DNS / service registrations. ---
      node_name: 'oracle-node-1',
      bind_addr: '10.200.0.11',
    },
  },
  nomad: {
    config: {
      # --- Per #32 the nomad node_name is the OS-hostname form with hyphens stripped (oraclenode1, NOT oracle-node-1); job constraints use `node.unique.name = "oraclenode1"`. ---
      node_name:    'oraclenode1',
      bind_addr:    '10.200.0.11',
      advertise_ip: '10.200.0.11',
    },
  },
  vault_cert_manager: {
    certificates: [
      {
        name:        'consul-client',
        role:        'consul-client',
        common_name: 'client.munchbox.consul',
        certificate: '/etc/consul.d/tls/consul.crt',
        key:         '/etc/consul.d/tls/consul.key',
        ttl:         '720h',
        alt_names:   %w(localhost oracle-node-1 oraclenode1 oracle-node-1.munchbox.cc client.munchbox.consul),
        ip_sans:     %w(10.200.0.11 127.0.0.1),
        owner:       'consul',
        group:       'consul',
        on_change:   'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
      {
        name:        'nomad-client',
        role:        'nomad-client',
        common_name: 'client.global.nomad',
        certificate: '/etc/nomad.d/tls/nomad.crt',
        key:         '/etc/nomad.d/tls/nomad.key',
        ttl:         '720h',
        alt_names:   %w(localhost oracle-node-1 oraclenode1 oracle-node-1.munchbox.cc client.global.nomad),
        ip_sans:     %w(10.200.0.11 127.0.0.1),
        owner:       'nomad',
        group:       'nomad',
        on_change:   'systemctl restart nomad',
        health_check: { tcp: '10.200.0.11:4646', timeout: '5s' },
      },
    ],
  },
  wireguard: {
    interfaces: {
      wg1: {
        address: '10.200.0.11/24',
        listen_port: 51820,
        mtu: 1380,
        vault_path: 'secret/data/wireguard-v2/oracle-node-1',
        vault_field: 'private_key',
        post_up: [
          'iptables -I INPUT -p udp --dport 51820 -j ACCEPT',
          'iptables -I INPUT -i wg1 -j ACCEPT',
        ],
        post_down: [
          'iptables -D INPUT -p udp --dport 51820 -j ACCEPT',
          'iptables -D INPUT -i wg1 -j ACCEPT',
        ],
        peers: [
          {
            'name'        => 'goren',
            'vault_path'  => 'secret/data/wireguard-v2/goren',
            'vault_field' => 'public_key',
            'allowed_ips' => ['10.201.0.2/32', '192.168.68.0/24'],
          },
          {
            'name'        => 'nc05',
            'vault_path'  => 'secret/data/wireguard-v2/nc05',
            'vault_field' => 'public_key',
            'allowed_ips' => ['10.201.0.3/32'],
          },
        ],
      },
    },
  }
)
