# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
# Recipe:: install
#
# Fetches the pinned cinc .deb directly from downloads.cinc.sh and
# installs via dpkg. No apt repository involved.
# -------------------------------------------------------------------------------

install = node[cookbook]['install']

cinc_client_install 'cinc' do
  version       install['version']
  package_name  install['package_name']
  download_base install['download_base']
  channel       install['channel']
  checksums     install['checksums']
end
