# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nvidia
# Resource:: nvidia_install
#
# Drops the debian non-free apt repo + the NVIDIA Container Toolkit apt
# repo, then installs the driver + container toolkit packages. Does NOT
# touch /etc/docker/daemon.json -- the `nvidia` runtime block is owned by
# the docker cookbook via docker.daemon.extra on the GPU node's role.
#
# Properties:
#   debian_nonfree_components  - Array of debian components (default
#                                main+contrib+non-free+non-free-firmware).
#   container_toolkit_repo_uri - NVIDIA toolkit apt repo URI (apt's
#                                `$(ARCH)` substitution is preserved).
#   container_toolkit_key_url  - URL of the NVIDIA toolkit signing key.
#   install_kernel_headers     - When true, pulls linux-headers-<running>
#                                so DKMS-style driver upgrades survive
#                                kernel updates.
#   packages                   - Apt packages to install.
# -------------------------------------------------------------------------------

unified_mode true

provides :nvidia_install

property :debian_nonfree_components,  Array,         default: %w(main contrib non-free non-free-firmware)
property :container_toolkit_repo_uri, String,        required: true
property :container_toolkit_key_url,  String,        required: true
property :install_kernel_headers,     [true, false], default: true
property :packages,                   Array,         default: %w(nvidia-driver nvidia-container-toolkit)

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Repos + driver + container toolkit
# -------------------------------------------------------------------------------

action :install do
  munchbox_base_apt_lock_wait 'nvidia_install_repos'

  # --- Debian non-free is signed by the debian-archive-keyring already in /usr/share/keyrings/. Using chef's apt_repository here would force a signed-by= pointing at an empty keyring (we have no URL for debian's own keys) and break bookworm signature verification. Plain file write keeps the default keyring in play. ---
  file '/etc/apt/sources.list.d/debian-nonfree.list' do
    content "deb http://deb.debian.org/debian #{node['lsb']['codename']} #{new_resource.debian_nonfree_components.join(' ')}\n"
    owner   'root'
    group   'root'
    mode    '0644'
    notifies :run, 'execute[apt-get update (debian-nonfree)]', :immediately
  end

  execute 'apt-get update (debian-nonfree)' do
    command 'apt-get update'
    action  :nothing
  end

  apt_repository 'nvidia-container-toolkit' do
    uri          new_resource.container_toolkit_repo_uri
    distribution '/'
    components   []
    key          new_resource.container_toolkit_key_url
    action       :add
  end

  munchbox_base_apt_lock_wait 'nvidia_install_packages'

  if new_resource.install_kernel_headers
    apt_package "linux-headers-#{node['kernel']['release']}" do
      action :install
    end
  end

  apt_package new_resource.packages do
    action :install
  end
end
