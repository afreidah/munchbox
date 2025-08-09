# # frozen_string_literal: true
#
# # ------------------------------------------------------------------------------
# #  consul_service_spec.rb — ChefSpec tests for consul_service custom resource
# # ------------------------------------------------------------------------------
#
# require 'spec_helper'
#
# describe 'consul_service resource' do
#   let(:chef_run) do
#     ChefSpec::SoloRunner.new(platform: 'debian', version: '12') do |node|
#       node.normal['consul'] = {
#         'user' => 'consul',
#         'group' => 'consul',
#         'data_dir' => '/opt/consul',
#         'config_dir' => '/etc/consul.d',
#         'install_dir' => '/usr/local/bin',
#       }
#     end.converge('test_cookbook::consul_service_test')
#   end
#
#   before do
#     allow(File).to receive(:exist?).and_return(false)
#     allow(File).to receive(:exist?).with('/run/systemd/system').and_return(true)
#   end
#
#   it 'creates systemd_unit[consul.service] with correct content' do
#     expect(chef_run).to create_systemd_unit('consul.service').with(
#       content: hash_including(
#         'Unit' => hash_including('Description' => 'Consul Agent'),
#         'Service' => hash_including(
#           'User' => 'consul',
#           'Group' => 'consul',
#           'ExecStart' => '/usr/local/bin/consul agent -config-dir=/etc/consul.d'
#         ),
#         'Install' => hash_including('WantedBy' => 'multi-user.target')
#       ),
#       action: [:create, :enable]
#     )
#   end
#
#   it 'notifies execute[systemctl-daemon-reload]' do
#     resource = chef_run.systemd_unit('consul.service')
#     expect(resource).to notify('execute[systemctl-daemon-reload]').to(:run).immediately
#   end
#
#   it 'enables and starts the consul service' do
#     expect(chef_run).to enable_service('consul')
#     expect(chef_run).to start_service('consul')
#   end
#
#   context 'when not using systemd' do
#     before do
#       allow(File).to receive(:exist?).and_return(false)
#     end
#
#     it 'creates /etc/init.d/consul template' do
#       expect(chef_run).to create_template('/etc/init.d/consul').with(
#         source: 'consul-init.erb',
#         mode: '0755',
#         owner: 'root',
#         group: 'root',
#         variables: hash_including(
#           consul_binary: '/usr/local/bin/consul',
#           config_dir: '/etc/consul.d',
#           data_dir: '/opt/consul',
#           user: 'consul',
#           group: 'consul'
#         )
#       )
#     end
#   end
# end
