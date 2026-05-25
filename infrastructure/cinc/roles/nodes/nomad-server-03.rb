# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad-server-03
#
# Per-node config for nomad-server-03 (192.168.68.58). x86_64 proxmox VM
# hosting the third consul+nomad+vault server alongside goren+stabler.
# Server-only (no client {} block); pure orchestrator/raft duty.
#
# NOT in role[bare_metal_pi5] -- ns-03 is x86_64, no ingress role, no
# batch/client workloads. Hand-lists the same server-tier layers Pi5s
# use minus the Pi5-specific bits (NFS gdrive mounts, ingress meta).
#
# Hostname is normalized to `nomad-server-03` at bootstrap time
# (previously the OS-hostname was `debian`, leaving nomad agent
# registering as `debian.global` while consul registered as
# `nomad-server-03` -- chef renders both with the same name). Cert SANs
# still include `debian` for backward compat with any caller hitting
# the old name.
# -------------------------------------------------------------------------------

name 'nomad-server-03'
description 'nomad-server-03: third consul+nomad+vault server (x86_64 proxmox VM, 192.168.68.58)'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- ssh CA wiring; safe after vault_agent so vault_fetch has a token. ---
  'recipe[munchbox_base::sshd_ca]',
  # --- vault PKI intermediate -> /opt/nomad/tls + system trust. ---
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  'role[consul_server]',
  # --- Local dnsmasq -> consul/CoreDNS routing; reads global.dns_endpoint_ip. ---
  'recipe[consul::dns]',
  'role[nomad_server]',
  # --- /etc/resolv.conf -> bind_addr (not 127.0.0.53) so nomad's docker driver doesn't trip its systemd-resolved heuristic. ---
  'recipe[munchbox_base::resolv_conf]',
  # --- Vault server takeover pilot. restart_on_change=false (cookbook default) so chef rewrites vault.hcl + systemd unit but does NOT bounce the daemon (shamir-sealed; restart = manual unseal x3). Next planned restart picks up chef config. ---
  'role[vault_server]'
)

default_attributes(
  global: {
    dns_endpoint_ip: '192.168.68.58',
  },
  consul: {
    config: {
      bind_addr:  '192.168.68.58',
      # --- Per-node since ns-03 isn't in role[bare_metal_pi5] (which carries the shared retry_join for the other two servers). ---
      retry_join: %w(192.168.68.61 192.168.68.60 192.168.68.58),
    },
  },
  vault: {
    config: {
      advertise_ip: '192.168.68.58',
      # --- Sweep ansible-era leftovers (multiple backup variants from the TLS-enable rollout). vault binary + .crt/.key NOT touched -- chef-managed cert lives at the same path. ---
      stale_paths: [
        '/etc/vault.d/vault.hcl.bak',
        '/etc/vault.d/vault.hcl.bak.20251125220955',
        '/etc/vault.d/vault.hcl.pre-tls.1764114979',
        '/etc/vault.d/tls/vault-csr.pem',
        '/etc/vault.d/tls/vault.crt.bak',
        '/etc/vault.d/tls/vault.key.bak',
      ],
    },
  },
  nomad: {
    config: {
      # --- Per-node identity (normalized to nomad-server-03 from previous hostname-defaulted `debian`). ---
      node_name:     'nomad-server-03',
      bind_addr:     '0.0.0.0',
      advertise_ip:  '192.168.68.58',
      server_join:   %w(192.168.68.61:4648 192.168.68.60:4648),
      vault_address: 'https://192.168.68.61:8200',
      # --- Sweep duplicate `server {}` block left by an earlier ansible play; in addition to the cookbook defaults. ---
      stale_paths: [
        '/etc/nomad.d/nomad.hcl.bak',
        '/etc/nomad.d/nomad.hcl.broken',
        '/etc/nomad.d/consul_token.env',
        '/etc/nomad.d/010-client-tags.hcl',
        '/etc/systemd/system/nomad.service.d/10-consul-token.conf',
        '/etc/nomad.d/server.hcl',
      ],
    },
  },
  # --- consul + nomad server cert defs; alt_names cover BOTH the old `debian` short-hostname and the normalized `nomad-server-03` so any caller still using `debian` keeps validating. ---
  vault_cert_manager: {
    certificates: [
      {
        name:         'consul-server',
        role:         'consul-server',
        common_name:  'server.munchbox.consul',
        certificate:  '/etc/consul.d/tls/consul.crt',
        key:          '/etc/consul.d/tls/consul.key',
        ttl:          '720h',
        alt_names:    %w(localhost debian nomad-server-03 nomad-server-03.munchbox.cc server.munchbox.consul),
        ip_sans:      %w(192.168.68.58 127.0.0.1),
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
        alt_names:    %w(localhost debian nomad-server-03 nomad-server-03.munchbox.cc server.global.nomad nomad.service.consul),
        ip_sans:      %w(192.168.68.58 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.58:4646', timeout: '5s' },
      },
      # --- Vault server cert. on_change uses SIGHUP (systemctl reload), NOT restart -- vault hot-reloads TLS without going sealed. owner=vault matches the daemon user. CN matches the cookbook-uniform pattern; `vault.munchbox.cc` stays in SANs for backward compat with the previous virtual-name CN. ---
      {
        name:         'vault-server',
        role:         'vault-server',
        common_name:  'nomad-server-03.munchbox.cc',
        certificate:  '/etc/vault.d/tls/vault.crt',
        key:          '/etc/vault.d/tls/vault.key',
        ttl:          '720h',
        alt_names:    %w(localhost debian nomad-server-03 nomad-server-03.munchbox.cc vault.munchbox.cc vault.service.consul),
        ip_sans:      %w(192.168.68.58 127.0.0.1),
        owner:        'vault',
        group:        'vault',
        on_change:    'systemctl reload vault',
        health_check: { tcp: '192.168.68.58:8200', timeout: '5s' },
      },
    ],
  }
)

override_attributes(
  # --- vault server already runs here; chef-managed vault-agent uses a separate config_dir + the existing /usr/local/bin/vault binary. Same pattern as the Pi5s. ---
  vault_agent: {
    binary_path: '/usr/local/bin/vault',
    config_dir:  '/etc/vault-agent.d',
    install:     { install_binary: false, mask_vault_service: false },
  }
)
