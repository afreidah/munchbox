# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Install
#
# Pinned to Docker CE from download.docker.com. Pulls the apt suite from
# the upstream repo. Per-node arch is detected at converge time via
# node['kernel']['machine'] (arm64 / amd64).
#
# `add_user_to_group` -- system user (or list of users) added to the docker
# group so they can drive docker.sock without root. Default 'nomad' (matches
# the existing fleet); roles override it (oracle adds 'ubuntu'). nil/[] to skip.
#
# `restart_on_group_add` -- service to restart after the group add, so it
# picks up the new GID. Default 'nomad'; nil to skip.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  packages: %w(docker-ce docker-ce-cli containerd.io docker-compose-plugin),
  remove_packages: %w(docker-buildx),
  prereq_packages: %w(apt-transport-https ca-certificates curl gnupg lsb-release),
  # --- key_url + repo_uri default to nil so the resource picks /linux/<platform> at converge time (ubuntu vs debian). Set explicitly here to pin. ---
  key_url: nil,
  repo_uri: nil,
  repo_component: 'stable',
  add_user_to_group: %w(nomad),
  dependent_service: 'nomad',
}

# -------------------------------------------------------------------------------
# Daemon config
#
# Templated into /etc/docker/daemon.json. `enabled` gates the recipe --
# nodes that don't want a chef-managed daemon.json can leave docker
# stock by setting docker.daemon.enabled = false in their role.
#
# `dns` is the most node-specific knob: oracle nodes should point at
# their local dnsmasq (see consul::dns) -- the recipe defaults to
# node[:consul][:dns][:host_ip] when not set explicitly, so adopting
# consul::dns + docker together keeps the wiring obvious.
# -------------------------------------------------------------------------------

default[cookbook]['daemon'] = {
  enabled: true,
  path: '/etc/docker/daemon.json',
  dns: nil,
  log_driver: 'json-file',
  log_max_file: '3',
  log_max_size: '10m',
  insecure_registries: ['registry.service.consul:5000'],
  live_restore: true,
  extra: {},
}
