# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Recipe:: install
#
# Downloads the cinc-server .deb and installs it. Idempotent: dpkg_package
# is a no-op once the package is present at the pinned version.
# -------------------------------------------------------------------------------

cinc_server_install 'cinc-server' do
  url      node[cookbook]['install']['url']
  version  node[cookbook]['install']['version']
  checksum node[cookbook]['install']['checksum']
end
