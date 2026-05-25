# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: goren
#
# Per-node config for goren (192.168.68.60) -- bare-metal Pi5, aarch64.
# One of two consul+nomad+vault servers, also holds the ingress VIP /
# traefik / haproxy / patroni primary / redis when MASTER.
# -------------------------------------------------------------------------------

name 'goren'
description 'goren: bare-metal Pi5 (192.168.68.60) -- consul+nomad+vault server'

run_list(
  'role[bare_metal_pi5]',
  # --- Vault server takeover (3rd pilot after ns-03 + stabler). restart_on_change=false so vault keeps its in-memory config (and stays unsealed) until next planned restart. ---
  'role[vault_server]'
)

default_attributes(
  global: {
    dns_endpoint_ip: '192.168.68.60',
  },
  consul: {
    config: {
      bind_addr: '192.168.68.60',
    },
  },
  vault: {
    config: {
      advertise_ip: '192.168.68.60',
      # --- Sweep ansible-era leftovers (backups + old CSR + auto-backup with `~` suffix). ---
      stale_paths: [
        '/etc/vault.d/vault.hcl.bak',
        '/etc/vault.d/vault.hcl.bak.20251125220954',
        '/etc/vault.d/vault.hcl.pre-tls.1764114982',
        '/etc/vault.d/vault.hcl.719198.2026-01-25@01:14:49~',
        '/etc/vault.d/tls/vault-csr.pem',
        '/etc/vault.d/tls/vault.crt.bak',
        '/etc/vault.d/tls/vault.key.bak',
      ],
    },
  },
  nomad: {
    config: {
      # --- Per-node identity ---
      node_name:     'goren',
      advertise_ip:  '192.168.68.60',
      server_join:   %w(192.168.68.61:4648 192.168.68.58:4648),
      vault_address: 'https://192.168.68.60:8200',
      # --- Folds /etc/nomad.d/010-client-tags.hcl into nomad.hcl. Effective runtime state from API pre-takeover: node_pool=default (010's batch was NOT winning), node_class=batch (from 010), meta merge of main {role=ingress, vrrp_interface=eth0} + 010 {zone=rack-a}. The standalone 010 file is swept by cookbook stale_paths. ---
      node_class: 'batch',
      client_meta: {
        'role'           => 'ingress',
        'vrrp_interface' => 'eth0',
        'zone'           => 'rack-a',
      },
    },
  },
  # --- consul + nomad cert defs. Single cert pair per service covers both server and client roles (nomad cert has client.global.nomad SAN; consul cert is shared by nomad's consul-API client block). ---
  vault_cert_manager: {
    certificates: [
      {
        name:         'consul-server',
        role:         'consul-server',
        common_name:  'server.munchbox.consul',
        certificate:  '/etc/consul.d/tls/consul.crt',
        key:          '/etc/consul.d/tls/consul.key',
        ttl:          '720h',
        alt_names:    %w(localhost goren goren.munchbox.cc server.munchbox.consul),
        ip_sans:      %w(192.168.68.60 127.0.0.1),
        owner:        'consul',
        group:        'consul',
        on_change:    'systemctl reload consul',
        health_check: { tcp: '127.0.0.1:8501', timeout: '5s' },
      },
      {
        name:         'nomad-server',
        role:         'nomad-server',
        common_name:  'server.global.nomad',
        certificate:  '/etc/nomad.d/tls/nomad.crt',
        key:          '/etc/nomad.d/tls/nomad.key',
        ttl:          '720h',
        alt_names:    %w(localhost goren goren.munchbox.cc server.global.nomad client.global.nomad nomad.service.consul),
        ip_sans:      %w(192.168.68.60 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.60:4646', timeout: '5s' },
      },
      # --- Vault server cert. on_change uses SIGHUP (systemctl reload) -- vault hot-reloads TLS without going sealed. ---
      {
        name:         'vault-server',
        role:         'vault-server',
        common_name:  'goren.munchbox.cc',
        certificate:  '/etc/vault.d/tls/vault.crt',
        key:          '/etc/vault.d/tls/vault.key',
        ttl:          '720h',
        alt_names:    %w(localhost goren goren.munchbox.cc vault.munchbox.cc vault.service.consul),
        ip_sans:      %w(192.168.68.60 127.0.0.1),
        owner:        'vault',
        group:        'vault',
        on_change:    'systemctl reload vault',
        health_check: { tcp: '192.168.68.60:8200', timeout: '5s' },
      },
    ],
  }
)

