# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# install recipe spec
#
# Covers the apt-package upgrade + config-dir creation. The package
# itself ships from the munchbox aptly repo registered earlier in the
# run_list by munchbox_base::apt_repo.
# -------------------------------------------------------------------------------

RSpec.describe 'vault_cert_manager::install' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('vault_cert_manager::install') }

  # --- Package upgrade so newer aptly builds get picked up on each converge ---
  it 'upgrades the vault-cert-manager apt package' do
    expect(chef_run).to upgrade_apt_package('vault-cert-manager')
  end

  # --- Config dir, root:root 0755 (vault-cert-manager runs as root and writes 0600 children itself) ---
  it 'creates /etc/vault-cert-manager with 0755 root:root' do
    expect(chef_run).to create_directory('/etc/vault-cert-manager')
      .with(owner: 'root', group: 'root', mode: '0755')
  end

  # --- Package notifies the daemon restart so a newer build kicks in ---
  it 'notifies vault-cert-manager restart (delayed) on package upgrade' do
    expect(chef_run.apt_package('vault-cert-manager'))
      .to notify('service[vault-cert-manager]').to(:restart).delayed
  end
end
