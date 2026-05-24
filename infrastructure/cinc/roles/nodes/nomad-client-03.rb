# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad-client-03
#
# Per-node config for nomad-client-03 (192.168.68.71) -- a proxmox VM
# running as a nomad+consul client.
# -------------------------------------------------------------------------------

name 'nomad-client-03'
description 'nomad-client-03: cluster nomad+consul client on a proxmox VM'

run_list(
  'role[proxmox_node]'
)

# --- consul-client + nomad-client cert defs. alt_names cover hostname + FQDN + the consul/nomad common-name forms; ip_sans = primary LAN IP + localhost. Matches what ansible's /etc/vault-cert-manager/config.yaml currently produces. ---
default_attributes(
  # --- Where local dnsmasq listens; consul::dns + docker::configure both read this so containers and the host resolve .consul via the local agent. ---
  global: {
    dns_endpoint_ip: '192.168.68.71',
  },
  consul: {
    config: {
      bind_addr: '192.168.68.71',
    },
  },
  nomad: {
    config: {
      node_name:    'nomad-client-03',
      advertise_ip: '192.168.68.71',
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
        alt_names:    %w(localhost nomad-client-03 nomad-client-03.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.71 127.0.0.1),
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
        alt_names:    %w(localhost nomad-client-03 nomad-client-03.munchbox.cc client.global.nomad),
        ip_sans:      %w(192.168.68.71 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.71:4646', timeout: '5s' },
      },
    ],
  }
)
