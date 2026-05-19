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
