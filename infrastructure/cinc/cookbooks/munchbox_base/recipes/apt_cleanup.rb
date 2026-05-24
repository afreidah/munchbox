# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: apt_cleanup
#
# Periodic apt autoremove + clean. Runs on every chef-client converge
# since both underlying commands are idempotent.
# -------------------------------------------------------------------------------

cfg = node[cookbook]['apt_cleanup']

munchbox_base_apt_cleanup 'baseline' do
  autoremove  cfg['autoremove']
  purge       cfg['purge']
  clean_cache cfg['clean_cache']
end
