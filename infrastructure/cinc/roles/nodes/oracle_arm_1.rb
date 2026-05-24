# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: oracle_arm_1
#
# Per-node role for oracle-arm-1. Composes role[oracle_node] (base + cinc +
# vault_agent + apt-daily disable) and adds the node-specific wg1
# WireGuard interface. Key material is referenced by Vault path; the
# wireguard cookbook fetches it at converge time via the Vault token
# vault-agent maintains at /run/vault-agent/token.
#
# Differs from oracle_arm_2 only in the wg1 interface address (10.200.0.13/24
# vs 10.200.0.14/24) and the Vault path for the local private key. Peer
# config (goren + nc05) is identical -- both Oracle nodes are siblings
# behind the same goren ingress.
# -------------------------------------------------------------------------------

name 'oracle_arm_1'
description 'oracle-arm-1 specific config (composes oracle_node + wireguard wg1)'

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
    dns_endpoint_ip: '10.200.0.13',
  },
  consul: {
    config: {
      # --- Match the existing catalog entry (ansible inventory hostname). Changing this would re-register the agent under a new identity and orphan its scrape configs / DNS / service registrations. ---
      node_name: 'oracle-arm-1',
      bind_addr: '10.200.0.13',
    },
  },
  nomad: {
    config: {
      # --- Per #32 the nomad node_name is the OS-hostname form with hyphens stripped (oraclearm1, NOT oracle-arm-1); job constraints use `node.unique.name = "oraclearm1"`. ---
      node_name:    'oraclearm1',
      bind_addr:    '10.200.0.13',
      advertise_ip: '10.200.0.13',
    },
  },
  vault_cert_manager: {
    # --- consul-client + nomad-client certs. alt_names include both the dashed (consul/vault-cert-manager) + dash-stripped (nomad) hostname forms so a cert is valid against both identities. ip_sans = WG IP + localhost. ---
    certificates: [
      {
        name:        'consul-client',
        role:        'consul-client',
        common_name: 'client.munchbox.consul',
        certificate: '/etc/consul.d/tls/consul.crt',
        key:         '/etc/consul.d/tls/consul.key',
        ttl:         '720h',
        alt_names:   %w(localhost oracle-arm-1 oraclearm1 oracle-arm-1.munchbox.cc client.munchbox.consul),
        ip_sans:     %w(10.200.0.13 127.0.0.1),
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
        alt_names:   %w(localhost oracle-arm-1 oraclearm1 oracle-arm-1.munchbox.cc client.global.nomad),
        ip_sans:     %w(10.200.0.13 127.0.0.1),
        owner:       'nomad',
        group:       'nomad',
        on_change:   'systemctl restart nomad',
        health_check: { tcp: '10.200.0.13:4646', timeout: '5s' },
      },
    ],
  },
  wireguard: {
    interfaces: {
      wg1: {
        address: '10.200.0.13/24',
        listen_port: 51820,
        mtu: 1380,
        vault_path: 'secret/data/wireguard-v2/oracle-arm-1',
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
