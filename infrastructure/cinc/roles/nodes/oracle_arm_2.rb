# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: oracle_arm_2
#
# Per-node role for oracle-arm-2. Composes role[oracle_node] (base + cinc +
# vault_agent + apt-daily disable) and adds the node-specific wg1
# WireGuard interface. Key material is referenced by Vault path; the
# wireguard cookbook fetches it at converge time via the Vault token
# vault-agent maintains at /run/vault-agent/token.
# -------------------------------------------------------------------------------

name 'oracle_arm_2'
description 'oracle-arm-2 specific config (composes oracle_node + wireguard wg1)'

run_list(
  'role[oracle_node]',
  'recipe[wireguard::install]',
  'recipe[wireguard::configure]',
  # --- Persists the OCI block volume (label minio-data) at /mnt/minio-data. Arm-only -- only minio hosts have the attached volume. ---
  'recipe[oracle::minio_mount]'
)

default_attributes(
  # --- Shared host DNS endpoint IP. consul::dns binds dnsmasq here; docker::configure points containers here. Set once per node; both cookbooks read it from node['global']. ---
  global: {
    dns_endpoint_ip: '10.200.0.14',
  },
  consul: {
    config: {
      # --- Match the existing catalog entry (ansible inventory hostname). Changing this would re-register the agent under a new identity and orphan its scrape configs / DNS / service registrations. ---
      node_name: 'oracle-arm-2',
      bind_addr: '10.200.0.14',
    },
  },
  nomad: {
    config: {
      # --- Per #32 the nomad node_name is the OS-hostname form with hyphens stripped (oraclearm2, NOT oracle-arm-2); job constraints use `node.unique.name = "oraclearm2"`. ---
      node_name:    'oraclearm2',
      bind_addr:    '10.200.0.14',
      advertise_ip: '10.200.0.14',
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
        alt_names:   %w(localhost oracle-arm-2 oraclearm2 oracle-arm-2.munchbox.cc client.munchbox.consul),
        ip_sans:     %w(10.200.0.14 127.0.0.1),
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
        alt_names:   %w(localhost oracle-arm-2 oraclearm2 oracle-arm-2.munchbox.cc client.global.nomad),
        ip_sans:     %w(10.200.0.14 127.0.0.1),
        owner:       'nomad',
        group:       'nomad',
        on_change:   'systemctl restart nomad',
        health_check: { tcp: '10.200.0.14:4646', timeout: '5s' },
      },
    ],
  },
  wireguard: {
    interfaces: {
      wg1: {
        address:     '10.200.0.14/24',
        listen_port: 51820,
        mtu:         1380,
        vault_path:  'secret/data/wireguard-v2/oracle-arm-2',
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
