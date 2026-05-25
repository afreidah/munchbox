# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: stabler
#
# Per-node config for stabler (192.168.68.61) -- bare-metal Pi5, aarch64.
# One of two consul+nomad+vault servers; takes over the ingress VIP /
# traefik / haproxy / patroni / redis when goren is down.
# -------------------------------------------------------------------------------

name 'stabler'
description 'stabler: bare-metal Pi5 (192.168.68.61) -- consul+nomad+vault server'

run_list(
  'role[bare_metal_pi5]',
  # --- AlertManager auto-restart receiver; stabler-only today (alertmanager.yml points at 192.168.68.61:9095). ---
  'recipe[nomad::auto_restart_webhook]',
  # --- Vault server takeover (2nd pilot after ns-03). restart_on_change=false so vault keeps its in-memory config (and stays unsealed) until next planned restart. ---
  'role[vault_server]'
)

default_attributes(
  global: {
    dns_endpoint_ip: '192.168.68.61',
  },
  consul: {
    config: {
      bind_addr: '192.168.68.61',
    },
  },
  nomad: {
    config: {
      # --- Per-node identity ---
      node_name:     'stabler',
      advertise_ip:  '192.168.68.61',
      server_join:   %w(192.168.68.60:4648 192.168.68.58:4648),
      vault_address: 'https://192.168.68.61:8200',
    },
  },
  vault: {
    config: {
      advertise_ip: '192.168.68.61',
      # --- Sweep ansible-era leftovers (backups + old CSR + the legacy vault-fullchain.crt that the ansible config used to serve; chef-rendered vault.hcl points at vault.crt, and post-1.15.4-to-2.0.1 restart the running daemon now serves leaf-only too). ---
      stale_paths: [
        '/etc/vault.d/vault.hcl.bak',
        '/etc/vault.d/vault.hcl.bak.20251125220953',
        '/etc/vault.d/vault.hcl.pre-tls.1764114982',
        '/etc/vault.d/vault.hcl.1070194.2026-01-25@01:14:33~',
        '/etc/vault.d/tls/vault-csr.pem',
        '/etc/vault.d/tls/vault.crt.bak.1765268187',
        '/etc/vault.d/tls/vault.key.bak.1765268187',
        '/etc/vault.d/tls/vault-fullchain.crt',
      ],
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
        alt_names:    %w(localhost stabler stabler.munchbox.cc server.munchbox.consul),
        ip_sans:      %w(192.168.68.61 127.0.0.1),
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
        alt_names:    %w(localhost stabler stabler.munchbox.cc server.global.nomad client.global.nomad nomad.service.consul),
        ip_sans:      %w(192.168.68.61 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.61:4646', timeout: '5s' },
      },
      # --- Vault server cert. on_change uses SIGHUP (systemctl reload) -- vault hot-reloads TLS without going sealed. ---
      {
        name:         'vault-server',
        role:         'vault-server',
        common_name:  'stabler.munchbox.cc',
        certificate:  '/etc/vault.d/tls/vault.crt',
        key:          '/etc/vault.d/tls/vault.key',
        ttl:          '720h',
        alt_names:    %w(localhost stabler stabler.munchbox.cc vault.munchbox.cc vault.service.consul),
        ip_sans:      %w(192.168.68.61 127.0.0.1),
        owner:        'vault',
        group:        'vault',
        on_change:    'systemctl reload vault',
        health_check: { tcp: '192.168.68.61:8200', timeout: '5s' },
      },
    ],
  }
)

