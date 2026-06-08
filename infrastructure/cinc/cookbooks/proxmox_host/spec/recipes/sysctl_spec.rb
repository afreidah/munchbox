# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# sysctl recipe spec -- verifies the hypervisor knobs are wired through the
# shared munchbox_base_sysctl drop-in (the resource itself is covered by
# munchbox_base's own specs).
# -------------------------------------------------------------------------------

RSpec.describe 'proxmox_host::sysctl' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new.converge(described_recipe)
  end

  it 'declares the proxmox-host sysctl drop-in with vm.swappiness lowered to 10' do
    expect(chef_run).to configure_munchbox_base_sysctl('proxmox-host')
      .with(path: '/etc/sysctl.d/99-proxmox-host.conf', settings: { 'vm.swappiness' => 10 })
  end
end
