# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cni
# Recipe:: install
#
# Drops containernetworking/plugins binaries into /opt/cni/bin. Required
# for nomad bridge networking + consul connect.
# -------------------------------------------------------------------------------

cookbook = 'cni'
install  = node[cookbook]['install']

cni_install 'baseline' do
  version     install['version']
  install_dir install['install_dir']
  release_url install['release_url']
end
