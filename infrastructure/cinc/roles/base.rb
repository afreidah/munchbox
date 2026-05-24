# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: base
#
# Baseline run_list for every chef-managed node. All the OS-level
# prerequisites every other role assumes are in place: apt repo
# registration, baseline packages, time sync, journald limits, sshd
# hardening. Compose other roles by including role[base] in their
# run_list so they always get this for free.
# -------------------------------------------------------------------------------

name 'base'
description 'OS-level baseline that every chef-managed node runs'

run_list(
  'recipe[munchbox_base::pki_trust]',
  'recipe[munchbox_base::apt_repo]',
  'recipe[munchbox_base::packages]',
  'recipe[munchbox_base::timesync]',
  'recipe[munchbox_base::journald]',
  'recipe[munchbox_base::sshd]',
  # --- Periodic apt autoremove + cache wipe; safe on every node, both commands are idempotent. ---
  'recipe[munchbox_base::apt_cleanup]',
  # --- Mask apt-daily.* timers so unattended-upgrades can't grab the apt lock mid-converge. ---
  'recipe[cinc_client::disable_apt_daily]',
  # --- Ignore IPv6 RAs cluster-wide. Deco mesh keeps broadcasting a bogus ::/64 prefix even with IPv6 disabled in its UI; that route hijacks v4-mapped v6 connect()s into local v6 listeners (caused chef downloads to hit traefik on the ingress with the wrong cert). ---
  'recipe[munchbox_base::disable_ipv6_ra]',
  # --- Cluster-wide kernel knobs (currently just vm.overcommit_memory=1 for Redis BGSAVE). ---
  'recipe[munchbox_base::sysctl]'
)
