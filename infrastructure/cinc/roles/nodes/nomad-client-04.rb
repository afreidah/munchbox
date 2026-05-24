# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: nomad-client-04
#
# Per-node config for nomad-client-04 (192.168.68.73) -- a proxmox VM
# running as a nomad+consul client. Has GPU passthrough for the media stack.
# -------------------------------------------------------------------------------

name 'nomad-client-04'
description 'nomad-client-04: cluster nomad+consul client on a proxmox VM (GPU host)'

run_list(
  'role[proxmox_node]',
  # --- GPU host: install nvidia driver + nvidia-container-toolkit. The `nvidia` docker runtime block in daemon.json is owned by docker.daemon.extra in this role's attributes (already present). ---
  'recipe[nvidia::install]'
)

# --- consul-client + nomad-client cert defs. alt_names cover hostname + FQDN + the consul/nomad common-name forms; ip_sans = primary LAN IP + localhost. Matches what ansible's /etc/vault-cert-manager/config.yaml currently produces. ---
default_attributes(
  # --- Where local dnsmasq listens; consul::dns + docker::configure both read this so containers and the host resolve .consul via the local agent. ---
  global: {
    dns_endpoint_ip: '192.168.68.73',
  },
  nfs: {
    client: {
      # --- Per-node addition: rubirosa exports its /tank ZFS pool (2x12TB mirrors) over NFS. Only nc-04 mounts it (media stack lives here). Matches the existing fstab device string exactly (IP, not hostname) so chef takes over silently. ---
      extra_mounts: [
        { mount_point: '/tank', device: '192.168.68.69:/tank' },
      ],
    },
  },
  consul: {
    config: {
      bind_addr: '192.168.68.73',
    },
  },
  nomad: {
    config: {
      node_name:    'nomad-client-04',
      advertise_ip: '192.168.68.73',
    },
  },
  # --- GPU host: preserve the nvidia container runtime block that ansible's nvidia role wrote into daemon.json. Without this, chef's docker::configure would wipe it and break the media stack on dockerd restart. ---
  docker: {
    daemon: {
      extra: {
        'runtimes' => {
          'nvidia' => {
            'args' => [],
            'path' => 'nvidia-container-runtime',
          },
        },
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
        alt_names:    %w(localhost nomad-client-04 nomad-client-04.munchbox.cc client.munchbox.consul),
        ip_sans:      %w(192.168.68.73 127.0.0.1),
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
        alt_names:    %w(localhost nomad-client-04 nomad-client-04.munchbox.cc client.global.nomad),
        ip_sans:      %w(192.168.68.73 127.0.0.1),
        owner:        'nomad',
        group:        'nomad',
        on_change:    'systemctl restart nomad',
        health_check: { tcp: '192.168.68.73:4646', timeout: '5s' },
      },
    ],
  }
)
