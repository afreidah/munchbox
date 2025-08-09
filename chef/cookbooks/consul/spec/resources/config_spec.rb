# # frozen_string_literal: true
#
# require 'chefspec'
#
# describe 'consul_config resource' do
#   let(:config_dir) { '/etc/consul.d' }
#   let(:install_dir) { '/opt/consul' }
#   let(:user) { 'consul' }
#   let(:group) { 'consul' }
#   let(:config_path) { File.join(config_dir, 'consul.hcl') }
#
#   context 'action :create' do
#     let(:chef_run) do
#       runner = ChefSpec::SoloRunner.new(
#         platform: 'ubuntu',
#         version: '22.04',
#         step_into: ['consul_config']
#       )
#       runner.converge do
#         consul_config 'default' do
#           config_dir config_dir
#           install_dir install_dir
#           user user
#           group group
#           action :create
#         end
#       end
#     end
#
#     it 'creates the consul.hcl template with correct attributes' do
#       expect(chef_run).to create_template(config_path).with(
#         source: 'consul.hcl.erb',
#         owner: user,
#         group: group,
#         mode: '0640',
#         sensitive: true
#       )
#     end
#   end
#
#   context 'action :delete' do
#     let(:chef_run) do
#       runner = ChefSpec::SoloRunner.new(step_into: ['consul_config']) do |node|
#         # set node attributes if needed
#       end
#       runner.converge do
#         consul_config 'default' do
#           config_dir config_dir
#           install_dir install_dir
#           user user
#           group group
#           action :delete
#         end
#       end
#     end
#
#     it 'deletes the consul.hcl file' do
#       expect(chef_run).to delete_file(config_path)
#     end
#   end
# end
#
# describe 'consul_config resource' do
#   let(:config_dir) { '/etc/consul.d' }
#   let(:install_dir) { '/opt/consul' }
#   let(:user) { 'consul' }
#   let(:group) { 'consul' }
#   let(:config_path) { File.join(config_dir, 'consul.hcl') }
#
#   context 'action :create' do
#     let(:chef_run) do
#       runner = ChefSpec::SoloRunner.new(step_into: ['consul_config']) do |node|
#         # set node attributes if needed
#       end
#       runner.converge do
#         consul_config 'default' do
#           config_dir config_dir
#           install_dir install_dir
#           user user
#           group group
#           action :create
#         end
#       end
#     end
#
#     it 'creates the consul.hcl template with correct attributes' do
#       expect(chef_run).to create_template(config_path).with(
#         source: 'consul.hcl.erb',
#         owner: user,
#         group: group,
#         mode: '0640',
#         sensitive: true
#       )
#     end
#   end
#
#   context 'action :delete' do
#     let(:chef_run) do
#       runner = ChefSpec::SoloRunner.new(step_into: ['consul_config']) do |node|
#         # set node attributes if needed
#       end
#       runner.converge do
#         consul_config 'default' do
#           config_dir config_dir
#           install_dir install_dir
#           user user
#           group group
#           action :delete
#         end
#       end
#     end
#
#     it 'deletes the consul.hcl file' do
#       expect(chef_run).to delete_file(config_path)
#     end
#   end
# end
