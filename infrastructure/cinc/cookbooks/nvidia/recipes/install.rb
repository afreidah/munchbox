# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nvidia
# Recipe:: install
#
# Drops the debian non-free apt repo + the NVIDIA Container Toolkit apt
# repo, then installs the driver + container toolkit packages so the
# `nvidia` docker runtime (declared via docker.daemon.extra elsewhere)
# can actually launch GPU containers.
# -------------------------------------------------------------------------------

install = node[cookbook]['install']

nvidia_install 'baseline' do
  debian_nonfree_components  install['debian_nonfree_components']
  container_toolkit_repo_uri install['container_toolkit_repo_uri']
  container_toolkit_key_url  install['container_toolkit_key_url']
  install_kernel_headers     install['install_kernel_headers']
  packages                   install['packages']
end
