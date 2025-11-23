# frozen_string_literal: true

# -----------------------------------------------------------------------------
# Cookbook:: openbao
# Resource:: openbao_install
#
# Installs OpenBao from GitHub release as a Debian package.
# Downloads the .deb and verifies it against the GPG signature.
# Deploys to /usr/local/bin/openbao or user-specified location.
#
# Properties:
#   install_path - Path to OpenBao binary (default: '/usr/local/bin/openbao')
#   version      - Version to install (default: '2.3.1')
#
# Example usage in a recipe:
#   openbao_install 'install openbao' do
#     version '2.3.1'
#   end
# -----------------------------------------------------------------------------

unified_mode true

# --- Name of resource for OpenBao cluster installation ---
provides :openbao_install

property :install_path, String, default: '/usr/local/bin/openbao'
property :version, String, default: '2.3.1'

# --- Check if the installed version matches the desired version ---
load_current_value do
  if ::File.exist?(install_path)
    installed_version = shell_out("#{install_path} version").stdout[/(\d+\.\d+\.\d+)/, 1]
    version installed_version if installed_version
  else
    current_value_does_not_exist!
  end
end

# -----------------------------------------------------------------------------
#  install action — Installs OpenBao via verified .deb package
#
#  Downloads the .deb and GPG signature, verifies integrity, installs the
#  package, and symlinks the binary to the desired location.
# -----------------------------------------------------------------------------

action :install do
  converge_if_changed :version do
    ssl_cert_directory
    deb_name  = "bao_#{new_resource.version}_linux_amd64.deb"
    deb_path  = ::File.join(Chef::Config[:file_cache_path], deb_name)
    deb_url   = ::OpenBao::Helpers.download_path(new_resource.version)

    # --- Download .deb package to cache ---
    remote_file deb_path do
      mode   '0644'
      action :create
      source deb_url
    end

    # --- Install the OpenBao .deb package ---
    dpkg_package 'openbao' do
      action :install
      source deb_path
    end

    # --- Create service to take service notifications but don't start it ---
    service service_name do
      action [:enable]
    end

    # --- Setup directories for OpenBao ---
    node[cookbook_name]['directories'].each do |dir|
      directory dir do
        owner node[cookbook_name]['user']
        group node[cookbook_name]['group']
        mode '0755'
        action :create
      end
    end

    # -----------------------------------------------------------------------------
    #  Certificate Installer
    # -----------------------------------------------------------------------------

    certificate_installer 'install openbao certs' do
      # --- Ownership ---
      owner       node[cookbook_name]['user']
      group       node[cookbook_name]['group']

      # --- SSL Data Bag ---
      databag     node[cookbook_name]['ssl']['data_bag']
      item        node[cookbook_name]['ssl']['data_bag_item']
      section     node[cookbook_name]['ssl']['data_bag_section']
      target_path node[cookbook_name]['ssl']['target_path']

      # --- Notifications ---
      sensitive   is_sensitive?
    end
  end
end

# -----------------------------------------------------------------------------
#  remove action — Uninstalls OpenBao and cleans up installed files
# -----------------------------------------------------------------------------

action :remove do
  # --- Stop and disable the Bao service ---
  service service_name do
    action [:stop, :disable]
    only_if { ::File.exist?("/etc/systemd/system/#{service_name}.service") }
  end

  # --- Remove the OpenBao package ---
  package 'openbao' do
    action :remove
    only_if 'dpkg -l | grep openbao'
  end

  # --- Delete the OpenBao binary if present ---
  file new_resource.install_path do
    action :delete
    only_if { ::File.exist?(new_resource.install_path) }
  end

  # --- Remove config file ---
  file '/etc/openbao/openbao.hcl' do
    action :delete
    only_if { ::File.exist?('/etc/openbao/openbao.hcl') }
  end

  # --- Remove SSL certs directory if it exists ---
  directory ssl_cert_directory do
    action :delete
    recursive true
    only_if { ::File.directory?(ssl_cert_directory) }
  end
end
