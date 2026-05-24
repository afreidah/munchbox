# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# configure recipe spec
#
# Two attribute shapes covered: server (oracle-style, ListenPort + iptables
# PostUp/Down + no per-peer Endpoint) and client (home-ingress-style, per-peer
# Endpoint + PersistentKeepalive). Both use literal key material (no Vault
# round-trip in chefspec).
# -------------------------------------------------------------------------------

RSpec.describe 'wireguard::configure' do
  context 'with no interfaces declared' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(wireguard_interface)).converge('wireguard::configure')
    end

    it 'does not template any wg config' do
      expect(chef_run.find_resource(:template, '/etc/wireguard/wg1.conf')).to be_nil
    end
  end

  context 'with a server-shape interface (oracle-style)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(wireguard_interface)) do |node|
        node.override[:wireguard][:interfaces] = {
          'wg1' => {
            'address' => '10.200.0.14/24',
            'listen_port' => 51820,
            'mtu' => 1380,
            'private_key' => 'PRIV-TEST',
            'post_up' => ['iptables -I INPUT -p udp --dport 51820 -j ACCEPT'],
            'post_down' => ['iptables -D INPUT -p udp --dport 51820 -j ACCEPT'],
            'peers' => [
              {
                'name' => 'goren',
                'public_key' => 'PEER-PUB-GOREN',
                'allowed_ips' => ['10.201.0.2/32', '192.168.68.0/24'],
              },
            ],
          },
        }
      end.converge('wireguard::configure')
    end

    it 'declares the wireguard_interface resource' do
      expect(chef_run).to configure_wireguard_interface('wg1')
    end

    it 'templates /etc/wireguard/wg1.conf with 0600 root:root' do
      expect(chef_run).to create_template('/etc/wireguard/wg1.conf')
        .with(owner: 'root', group: 'root', mode: '0600')
    end

    it 'enables wg-quick@wg1 (no :start -- template notify-restart handles bringing it up)' do
      expect(chef_run).to enable_service('wg-quick@wg1')
    end

    it 'reloads wg-quick@wg1 via the down+reset-failed+up execute on config change (delayed)' do
      template = chef_run.template('/etc/wireguard/wg1.conf')
      expect(template).to notify('execute[reload wg-quick@wg1]').to(:run).delayed
    end

    it 'declares the reload execute as :nothing so it only runs when notified' do
      expect(chef_run.execute('reload wg-quick@wg1')).to do_nothing
    end

    it 'renders server-shape template variables (ListenPort + iptables postup)' do
      template = chef_run.template('/etc/wireguard/wg1.conf')
      expect(template.variables[:address]).to eq('10.200.0.14/24')
      expect(template.variables[:listen_port]).to eq(51820)
      expect(template.variables[:post_up]).to include(match(/iptables -I INPUT/))
      expect(template.variables[:peers].first['name']).to eq('goren')
      expect(template.variables[:peers].first['public_key']).to eq('PEER-PUB-GOREN')
    end
  end

  context 'with a client-shape interface (home-ingress-style)' do
    cached(:chef_run) do
      ChefSpec::SoloRunner.new(step_into: %w(wireguard_interface)) do |node|
        node.override[:wireguard][:interfaces] = {
          'wg1' => {
            'address' => '10.201.0.2/24',
            'mtu' => 1380,
            'private_key' => 'PRIV-TEST',
            'peers' => [
              {
                'name' => 'oracle-arm-2',
                'public_key' => 'PEER-PUB-ORACLE',
                'endpoint' => '137.131.39.64:51820',
                'allowed_ips' => ['10.200.0.14/32'],
                'persistent_keepalive' => 25,
              },
            ],
          },
        }
      end.converge('wireguard::configure')
    end

    it 'omits ListenPort + renders per-peer endpoint + keepalive' do
      template = chef_run.template('/etc/wireguard/wg1.conf')
      expect(template.variables[:listen_port]).to be_nil
      peer = template.variables[:peers].first
      expect(peer['endpoint']).to eq('137.131.39.64:51820')
      expect(peer['persistent_keepalive']).to eq(25)
    end
  end

  context 'when literal keys are missing and vault_path is not set' do
    it 'raises an actionable error' do
      runner = ChefSpec::SoloRunner.new(step_into: %w(wireguard_interface), log_level: :fatal) do |node|
        node.override[:wireguard][:interfaces] = {
          'wg1' => {
            'address' => '10.0.0.1/24',
          },
        }
      end
      # --- Chef prints the raised error to stdout before rspec catches it; silence to keep the spec output clean ---
      orig_stdout = $stdout
      $stdout = StringIO.new
      begin
        expect { runner.converge('wireguard::configure') }
          .to raise_error(/neither private_key nor vault_path is set/)
      ensure
        $stdout = orig_stdout
      end
    end
  end
end
