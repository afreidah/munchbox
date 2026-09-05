# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cni
# Resource:: cni_install
#
# Idempotent install of containernetworking/plugins. Skips download +
# extract when /opt/cni/bin/.cni-version already records the requested
# version. Arch is derived from node['kernel']['machine'] (x86_64=amd64,
# aarch64=arm64) so the same recipe works on proxmox VMs and bare-metal Pi5s.
#
# Properties:
#   version      - CNI plugins release tag (without the leading "v").
#   install_dir  - Where to extract binaries (default /opt/cni/bin).
#   release_url  - GitHub releases base URL.
# -------------------------------------------------------------------------------

unified_mode true

provides :cni_install

property :version,     String, required: true
property :install_dir, String, default: '/opt/cni/bin'
property :release_url, String, default: 'https://github.com/containernetworking/plugins/releases/download'

default_action :install

# -------------------------------------------------------------------------------
# Action :install
# -------------------------------------------------------------------------------

action :install do
  arch = case node['kernel']['machine']
         when 'x86_64'  then 'amd64'
         when 'aarch64' then 'arm64'
         else raise "unsupported arch #{node['kernel']['machine']} for cni_install"
         end

  version_stamp = ::File.join(new_resource.install_dir, '.cni-version')
  tarball       = "/tmp/cni-plugins-linux-#{arch}-v#{new_resource.version}.tgz"
  url           = "#{new_resource.release_url}/v#{new_resource.version}/cni-plugins-linux-#{arch}-v#{new_resource.version}.tgz"

  directory new_resource.install_dir do
    owner     'root'
    group     'root'
    mode      '0755'
    recursive true
    # --- no not_if guard: tar extract below stomps the dir mode to 0775 from the archive's leading `./` entry; chef re-enforces 0755 on every converge ---
  end

  already_installed = ::File.exist?(version_stamp) &&
                      ::File.read(version_stamp).strip == "v#{new_resource.version}"

  unless already_installed
    # --- curl, not chef remote_file: even with accept_ra=0 + RA routes flushed, ruby 3.4 Net::HTTP somehow still picks [::1]:443 as a connect candidate for github.com on nc-05 (where traefik answers on [::]:443 and the SSL handshake fails with a wrong cert). curl resolves only the v4 candidate and never touches the v6 path. ---
    execute "download cni plugins v#{new_resource.version}" do
      command "curl -fsSL -4 -o #{tarball} #{url}"
      user    'root'
      action  :run
    end

    archive_file "extract cni plugins v#{new_resource.version}" do
      path        tarball
      destination new_resource.install_dir
      owner       'root'
      group       'root'
      action      :extract
    end

    file version_stamp do
      content "v#{new_resource.version}\n"
      owner   'root'
      group   'root'
      mode    '0644'
      action  :create
    end

    file tarball do
      action :delete
    end
  end
end
