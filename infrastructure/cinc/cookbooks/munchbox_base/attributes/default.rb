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
  ca-certificates
  curl
  dnsutils
  git
  gnupg
  htop
  jq
  lsb-release
  net-tools
  tmux
  unattended-upgrades
  vim
)

# -------------------------------------------------------------------------------
# Munchbox apt repo
#
# Source list entry for the internal aptly-published repo (s3-backed, served
# via traefik). Cookbooks that install custom .debs (e.g. moat, cinc) rely on
# this being present.
# -------------------------------------------------------------------------------

default[cookbook]['apt_repo'] = {
  'name' => 'munchbox',
  'uri' => 'https://apt.munchbox.cc',
  'distribution' => 'stable',
  'components' => %w(main),
  'key_url' => 'https://apt.munchbox.cc/pubkey.asc',
}

# -------------------------------------------------------------------------------
# Time sync (systemd-timesyncd)
#
# Override `ntp_servers` if you want to point at internal NTP. The fallback
# pool keeps drift sane out of the box on fresh provisions.
# -------------------------------------------------------------------------------

default[cookbook]['timesync'] = {
  'service' => 'systemd-timesyncd',
  'ntp_servers' => %w(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org),
  'fallback_servers' => %w(time.cloudflare.com time.google.com),
}

# -------------------------------------------------------------------------------
# Journald limits
#
# Bound how much disk journald can eat and how long entries stick around.
# Bytes accept K/M/G suffixes; retention takes systemd time spans.
# -------------------------------------------------------------------------------

default[cookbook]['journald'] = {
  'system_max_use' => '2G',
  'system_keep_free' => '500M',
  'runtime_max_use' => '200M',
  'max_retention_sec' => '2week',
  'max_level_store' => 'info',
  'compress' => 'yes',
}

# -------------------------------------------------------------------------------
# Sshd hardening
#
# Tunable directives merged into /etc/ssh/sshd_config (which we template
# wholesale -- see munchbox_base::sshd). Add/override here rather than
# editing the template.
# -------------------------------------------------------------------------------

default[cookbook]['ssh'] = {
  'permit_root_login' => 'prohibit-password',
  'password_authentication' => 'no',
  'challenge_response_authentication' => 'no',
  'pubkey_authentication' => 'yes',
  'max_auth_tries' => 3,
  'login_grace_time' => '30s',
  'client_alive_interval' => 300,
  'client_alive_count_max' => 2,
  'x11_forwarding' => 'no',
}
