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
  'recipe[munchbox_base::apt_repo]',
  'recipe[munchbox_base::packages]',
  'recipe[munchbox_base::timesync]',
  'recipe[munchbox_base::journald]',
  'recipe[munchbox_base::sshd]'
)
