# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'wireguard::install' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(wireguard_install)).converge('wireguard::install')
  end

  it 'declares the wireguard_install resource' do
    expect(chef_run).to install_wireguard_install('wireguard')
  end

  it 'installs the wireguard packages' do
    expect(chef_run).to install_package(%w(wireguard wireguard-tools iptables))
  end

  it 'creates /etc/wireguard with 0700 root:root' do
    expect(chef_run).to create_directory('/etc/wireguard')
      .with(owner: 'root', group: 'root', mode: '0700')
  end

  it 'writes the ip_forward sysctl drop-in' do
    expect(chef_run).to create_file('/etc/sysctl.d/99-wireguard-ip-forward.conf')
      .with(owner: 'root', group: 'root', mode: '0644', content: "net.ipv4.ip_forward = 1\n")
  end

  it 'reloads sysctl only when the drop-in changes (notify-only)' do
    expect(chef_run.execute('wireguard sysctl reload')).to do_nothing
    expect(chef_run.file('/etc/sysctl.d/99-wireguard-ip-forward.conf'))
      .to notify('execute[wireguard sysctl reload]').to(:run).immediately
  end
end
