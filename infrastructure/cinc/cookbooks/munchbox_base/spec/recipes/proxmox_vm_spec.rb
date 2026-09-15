# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# proxmox_vm recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::proxmox_vm' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_packages))
                        .converge('munchbox_base::proxmox_vm')
  end

  # --- Wrapping resource gets credit for coverage + carries the package list ---
  it 'declares the proxmox-vm packages resource with the guest agent' do
    expect(chef_run).to install_munchbox_base_packages('proxmox-vm')
      .with(packages: %w(qemu-guest-agent))
  end

  # --- Underlying package resource installs the guest agent ---
  it 'installs the guest agent' do
    expect(chef_run).to install_package('proxmox-vm')
      .with(package_name: %w(qemu-guest-agent))
  end

  # --- Static unit cannot be enabled, so the recipe only starts it ---
  it 'starts the guest agent service' do
    expect(chef_run).to start_service('qemu-guest-agent')
  end

  it 'does not try to enable the static unit' do
    expect(chef_run).to_not enable_service('qemu-guest-agent')
  end
end
