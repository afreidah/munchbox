# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
# Resource:: vault_agent_install
#
# Registers HashiCorp's apt repo and installs the `vault` binary. The
# upstream `vault.service` unit (server mode) is left masked because we
# only run vault as an agent here; configure recipe drops its own
# vault-agent.service unit.
#
# Properties:
#   package_name - apt package (default 'vault').
#   apt_repo_uri - HashiCorp apt repo base URL.
#   apt_repo_key - URL of the signing key.
# -------------------------------------------------------------------------------

unified_mode true

provides :vault_agent_install

property :package_name,        String,        required: true
property :apt_repo_uri,        String,        required: true
property :apt_repo_key,        String,        required: true
# --- false on vault servers; binary lives outside apt ---
property :install_binary,      [true, false], default: true
# --- false on vault servers; vault.service IS the server unit there ---
property :mask_vault_service,  [true, false], default: true
property :config_dir,          String,        default: '/etc/vault.d'

default_action :install

# -------------------------------------------------------------------------------
# Action :install
# -------------------------------------------------------------------------------

action :install do
  if new_resource.install_binary
    munchbox_base_apt_lock_wait 'vault_agent_install'

    apt_update 'vault_agent_install' do
      action :periodic
    end

    package %w(gnupg apt-transport-https ca-certificates) do
      action :install
    end

    apt_repository 'hashicorp' do
      uri          new_resource.apt_repo_uri
      components   %w(main)
      key          new_resource.apt_repo_key
      action       :add
    end

    apt_package new_resource.package_name do
      action :install
    end
  end

  if new_resource.mask_vault_service
    systemd_unit 'vault.service' do
      action :mask
    end
  end

  directory new_resource.config_dir do
    owner 'root'
    group 'root'
    mode  '0700'
  end
end

# -------------------------------------------------------------------------------
# Action :remove
# -------------------------------------------------------------------------------

action :remove do
  if new_resource.mask_vault_service
    systemd_unit 'vault.service' do
      action :unmask
    end
  end

  if new_resource.install_binary
    apt_package new_resource.package_name do
      action :remove
    end
  end
end
