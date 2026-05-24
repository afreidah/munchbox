# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: packages
#
# Installs the baseline apt package set every Munchbox node depends on.
# -------------------------------------------------------------------------------

munchbox_base_packages 'baseline' do
  packages node[cookbook]['packages']
end

# --- Purge anything we explicitly don't want installed (ansible-era residue). ---
purge = node[cookbook]['packages_purge']
apt_package 'munchbox_base purge list' do
  package_name purge
  action       :purge
  only_if      { purge && !purge.empty? }
end
