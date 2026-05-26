# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Attributes:: default
#
# Defaults for the wide base cookbook. Every entry is keyed under the
# cookbook's namespace via `node[cookbook]`, so renaming the cookbook is a
# one-line change in metadata.rb.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Apt packages
#
# Set installed on every Munchbox node. Keep this short -- anything specific to
# a service belongs in that service's cookbook, not here.
# -------------------------------------------------------------------------------

default[cookbook]['packages'] = %w(
  apt-transport-https
  bind9-dnsutils
  ca-certificates
  curl
  git
  gnupg
  htop
  jq
  lsb-release
  net-tools
  tmux
  vim-nox
)

# --- Packages to purge cluster-wide. unattended-upgrades is here because chef owns apt cadence now (apt-daily timers masked, apt_cleanup runs on every converge); leaving u-u installed re-creates apt-lock contention and runs upgrades chef didn't authorize. ---
default[cookbook]['packages_purge'] = %w(
  unattended-upgrades
)

# -------------------------------------------------------------------------------
# Munchbox apt repo
#
# Source list entry for the internal aptly-published repo (s3-backed, served
# via traefik). Cookbooks that install custom .debs (e.g. moat, cinc) rely on
# this being present.
# -------------------------------------------------------------------------------

default[cookbook]['apt_repo'] = {
  name: 'munchbox',
  uri: 'https://apt.munchbox.cc',
  distribution: 'stable',
  components: %w(main),
  key_url: 'https://apt.munchbox.cc/pubkey.asc',
}

# -------------------------------------------------------------------------------
# Time sync (systemd-timesyncd)
#
# Override `ntp_servers` if you want to point at internal NTP. The fallback
# pool keeps drift sane out of the box on fresh provisions.
# -------------------------------------------------------------------------------

default[cookbook]['timesync'] = {
  # --- Skip the timesync recipe entirely on hosts that already run a different time daemon (e.g. chrony on the Pi5 bare metals). Set to false in the host's role to opt out. ---
  enabled: true,
  service: 'systemd-timesyncd',
  ntp_servers: %w(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org),
  fallback_servers: %w(time.cloudflare.com time.google.com),
}

# -------------------------------------------------------------------------------
# Journald limits
#
# Bound how much disk journald can eat and how long entries stick around.
# Bytes accept K/M/G suffixes; retention takes systemd time spans.
# -------------------------------------------------------------------------------

default[cookbook]['journald'] = {
  system_max_use: '2G',
  system_keep_free: '500M',
  runtime_max_use: '200M',
  max_retention_sec: '2week',
  max_level_store: 'info',
  compress: 'yes',
}

# -------------------------------------------------------------------------------
# Sshd hardening
#
# Tunable directives merged into /etc/ssh/sshd_config (which we template
# wholesale -- see munchbox_base::sshd). Add/override here rather than
# editing the template.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Rsyslog rotation
#
# Tighter logrotate fragment for /etc/logrotate.d/rsyslog. Defaults match
# the ansible play that this replaces: daily + 200M size trigger so a
# rogue syslog (e.g. docker spam on oracle-arm) can't grow unbounded.
# Only applied where this recipe is in the run_list -- not in the cookbook
# default suite, since bare-metal boxes don't have the same disk pressure.
# -------------------------------------------------------------------------------

default[cookbook]['rsyslog_rotation'] = {
  config_path: '/etc/logrotate.d/rsyslog',
  log_files: %w(
    /var/log/syslog
    /var/log/mail.log
    /var/log/kern.log
    /var/log/auth.log
    /var/log/user.log
    /var/log/cron.log
  ),
  rotate: 7,
  frequency: 'daily',
  size: '200M',
  compress: true,
  delaycompress: true,
  missingok: true,
  notifempty: true,
  su_user: 'root',
  su_group: 'syslog',
  postrotate: '/usr/lib/rsyslog/rsyslog-rotate',
  force_on_change: true,
}

# -------------------------------------------------------------------------------
# Apt cleanup
#
# Knobs for the periodic autoremove + cache wipe. Defaults match the
# ansible play this replaces (autoremove --purge + apt clean).
# -------------------------------------------------------------------------------

default[cookbook]['apt_cleanup'] = {
  autoremove: true,
  purge: true,
  clean_cache: true,
}

# -------------------------------------------------------------------------------
# /etc/resolv.conf
#
# Points the host at the local dnsmasq. We use the node's primary IP
# (where dnsmasq's second listen-address is bound) instead of 127.0.0.53
# because nomad's docker driver has a hardcoded heuristic: if it sees
# `nameserver 127.0.0.53` in /etc/resolv.conf, it assumes systemd-resolved
# is running and tries to read /run/systemd/resolve/resolv.conf as the
# bind-mount source for container resolv.conf. On these nodes that file
# doesn't exist (we run dnsmasq, not systemd-resolved) -- bridge-network
# allocs fail at container creation with "failed to build mount for
# resolv.conf". Using the host IP nameserver instead bypasses the
# detection entirely. dnsmasq listens on both 127.0.0.53 and the host IP
# (per consul::dns), so traffic still resolves the same way.
#
# `nameserver` defaults to nil -- the recipe falls back to
# node['global']['dns_endpoint_ip'] (the same value consul::dns and
# docker::configure already read for their local-resolver wiring).
# -------------------------------------------------------------------------------

default[cookbook]['resolv_conf'] = {
  path: '/etc/resolv.conf',
  search: 'munchbox.cc',
  nameserver: nil,
}

# -------------------------------------------------------------------------------
# Disable IPv6 RA
#
# The Deco mesh router keeps emitting Router Advertisements with prefix
# ::/64 even with IPv6 disabled in its UI. That installs an on-link route
# covering the v4-mapped v6 space, which causes ruby Net::HTTP Happy-
# Eyeballs to short-circuit v4 connections through local v6 wildcard
# listeners (e.g. traefik on the ingress). Cluster is v4-only, so ignore
# RAs on every host.
# -------------------------------------------------------------------------------

default[cookbook]['disable_ipv6_ra'] = {
  sysctl_path: '/etc/sysctl.d/99-disable-ipv6-ra.conf',
}

# -------------------------------------------------------------------------------
# Sysctl
#
# Cluster-wide kernel knobs. vm.overcommit_memory=1 is for Redis BGSAVE:
# the fork()+COW pattern needs the kernel to allow optimistic
# allocations or the snapshot fails under memory pressure (Redis prints
# a startup warning when overcommit_memory != 1). Setting is benign for
# everything else.
# -------------------------------------------------------------------------------

default[cookbook]['sysctl'] = {
  path: '/etc/sysctl.d/99-munchbox.conf',
  settings: {
    'vm.overcommit_memory' => 1,
  },
}

default[cookbook]['ssh'] = {
  permit_root_login: 'prohibit-password',
  password_authentication: 'no',
  challenge_response_authentication: 'no',
  pubkey_authentication: 'yes',
  max_auth_tries: 3,
  login_grace_time: '30s',
  client_alive_interval: 300,
  client_alive_count_max: 2,
  x11_forwarding: 'no',
}

# -------------------------------------------------------------------------------
# SSH CA (Vault SSH secrets backend)
#
# Consumed by munchbox_base::sshd_ca. Reads-only Phase 1: trusted user CA
# pubkey + authorized_principals files + sshd_config drop-in + break-glass
# key. Host cert + inter-node client cert signing stay in the ansible
# ssh-ca-setup playbook (those are Vault writes that need a Vault policy
# update before chef can sign on every converge).
#
# Opt nodes in by adding `recipe[munchbox_base::sshd_ca]` to the run_list
# (AFTER role[vault_agent]). `principals` maps username -> list of valid
# principals (contents of /etc/ssh/authorized_principals/<user>). Per-fleet
# roles override to add users like 'ubuntu' on oracle nodes.
# -------------------------------------------------------------------------------

default[cookbook]['vault_pki_trust'] = {
  mount: 'pki_int',
  destinations: [
    '/opt/nomad/tls/vault-intermediate-ca.pem',
    '/usr/local/share/ca-certificates/vault-pki-ca.crt',
    { 'path' => '/etc/consul.d/tls/ca-chain.crt', 'owner' => 'consul', 'group' => 'consul', 'mode' => '0644', 'chain' => true },
  ],
  reload_docker: true,
  # --- Files ansible's distribute-vault-pki-ca / consul-enable-tls used to drop. Chef writes its CA to vault-intermediate-ca.pem now; these legacy names are ignored by everything but still sit on disk confusing operators. ---
  stale_paths: %w(
    /opt/nomad/tls/vault-ca-chain.pem
    /opt/nomad/tls/nomad-agent-ca.pem
  ),
}

default[cookbook]['etc_hosts'] = {
  hosts_path: '/etc/hosts',
  domain: 'munchbox.cc',
  marker_begin: '# BEGIN MUNCHBOX CLUSTER HOSTS',
  marker_end: '# END MUNCHBOX CLUSTER HOSTS',
  ip_attribute_path: %w(consul config bind_addr),
  cloud_init_dropin: '/etc/cloud/cloud.cfg.d/99-disable-manage-hosts.cfg',
  # --- Hosts not yet under chef (pihole/unbound boxes on original Pis); appended after chef-search results ---
  static_entries: [
    { 'ip' => '192.168.68.62', 'hostname' => 'green' },
    { 'ip' => '192.168.68.64', 'hostname' => 'logan' },
  ],
}

default[cookbook]['ssh_ca'] = {
  trusted_user_ca_path: '/etc/ssh/trusted-user-ca-keys.pem',
  host_cert_path: '/etc/ssh/ssh_host_ed25519_key-cert.pub',
  principals_dir: '/etc/ssh/authorized_principals',
  principals: { 'root' => ['root'] },
  client_signer_vault_path: 'ssh-client-signer/config/ca',
  client_signer_vault_field: 'public_key',
  host_signer_vault_path: 'ssh-host-signer/config/ca',
  host_signer_vault_field: 'public_key',
  manage_break_glass: true,
  break_glass_vault_path: 'secret/data/ssh/break-glass',
  break_glass_vault_field: 'public_key',
  break_glass_users: ['root'],
}
