#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook:: firewall
# Resource:: default
#
# Copyright:: 2011-2019, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class Chef
  class Provider::FirewallIptablesUbuntu < Chef::Provider::LWRPBase
    include FirewallCookbook::Helpers
    include FirewallCookbook::Helpers::Iptables

    provides :firewall, os: 'linux' do |node|
      node['firewall']['solution'] == 'iptables' && node['platform_family'] == 'debian'
    end

    def whyrun_supported?
      false
    end

    action :install do
      return if disabled?(new_resource)

      # Ensure the package is installed
      pkg = package 'iptables-persistent' do
        action :nothing
      end
      pkg.run_action(:install)
      new_resource.updated_by_last_action(true) if pkg.updated_by_last_action?

      rule_files = %w(rules.v4)
      rule_files << 'rules.v6' if ipv6_enabled?(new_resource)
      rule_files.each do |svc|
        next if ::File.exist?("/etc/iptables/#{svc}")

        # must create empty file for service to start
        f = lookup_or_create_rulesfile(svc)
        f.content '# created by chef to allow service to start'
        f.run_action(:create)

        new_resource.updated_by_last_action(true) if f.updated_by_last_action?
      end

      iptables_service = lookup_or_create_service('netfilter-persistent')
      [:enable, :start].each do |act|
        # iptables-persistent isn't a real service
        iptables_service.status_command 'true'

        iptables_service.run_action(act)
        new_resource.updated_by_last_action(true) if iptables_service.updated_by_last_action?
      end
    end

    action :restart do
      return if disabled?(new_resource)

      # prints all the firewall rules
      log_iptables(new_resource)

      # ensure it's initialized
      new_resource.rules({}) unless new_resource.rules
      ensure_default_rules_exist(node, new_resource)

      # this populates the hash of rules from firewall_rule resources
      firewall_rules = Chef.run_context.resource_collection.select { |item| item.resource_name == :firewall_rule }
      firewall_rules.each do |firewall_rule|
        next unless firewall_rule.action.include?(:create) && !firewall_rule.should_skip?(:create)

        types = if ipv6_rule?(firewall_rule) # an ip4 specific rule
                  %w(ip6tables)
                elsif ipv4_rule?(firewall_rule) # an ip6 specific rule
                  %w(iptables)
                else # or not specific
                  %w(iptables ip6tables)
                end

        types.each do |iptables_type|
          # build rules to apply with weight
          k = build_firewall_rule(node, firewall_rule, iptables_type == 'ip6tables')
          v = firewall_rule.position

          # unless we're adding them for the first time.... bail out.
          next if new_resource.rules[iptables_type].key?(k) && new_resource.rules[iptables_type][k] == v
          new_resource.rules[iptables_type][k] = v
        end
      end

      restart_service = false

      rule_files = %w(iptables)
      rule_files << 'ip6tables' if ipv6_enabled?(new_resource)

      rule_files.each do |iptables_type|
        iptables_filename = if iptables_type == 'ip6tables'
                              '/etc/iptables/rules.v6'
                            else
                              '/etc/iptables/rules.v4'
                            end

        # ensure a file resource exists with the current iptables rules
        begin
          iptables_file = Chef.run_context.resource_collection.find(file: iptables_filename)
        rescue
          iptables_file = file iptables_filename do
            action :nothing
          end
        end
        iptables_file.content build_rule_file(new_resource.rules[iptables_type])
        iptables_file.run_action(:create)

        # if the file was changed, restart iptables
        restart_service = true if iptables_file.updated_by_last_action?
      end

      if restart_service
        service_affected = service 'netfilter-persistent' do
          action :nothing
        end
        service_affected.run_action(:restart)
        new_resource.updated_by_last_action(true)
      end
    end

    action :disable do
      return if disabled?(new_resource)

      iptables_flush!(new_resource)
      iptables_default_allow!(new_resource)
      new_resource.updated_by_last_action(true)

      iptables_service = lookup_or_create_service('netfilter-persistent')
      [:disable, :stop].each do |act|
        iptables_service.run_action(act)
        new_resource.updated_by_last_action(true) if iptables_service.updated_by_last_action?
      end

      %w(rules.v4 rules.v6).each do |svc|
        # must create empty file for service to start
        f = lookup_or_create_rulesfile(svc)
        f.content '# created by chef to allow service to start'
        f.run_action(:create)

        new_resource.updated_by_last_action(true) if f.updated_by_last_action?
      end
    end

    action :flush do
      return if disabled?(new_resource)

      iptables_flush!(new_resource)
      new_resource.updated_by_last_action(true)

      rule_files = %w(rules.v4)
      rule_files << 'rules.v6' if ipv6_enabled?(new_resource)
      rule_files.each do |svc|
        # must create empty file for service to start
        f = lookup_or_create_rulesfile(svc)
        f.content '# created by chef to allow service to start'
        f.run_action(:create)

        new_resource.updated_by_last_action(true) if f.updated_by_last_action?
      end
    end

    def lookup_or_create_service(name)
      begin
        iptables_service = Chef.run_context.resource_collection.find(service: svc)
      rescue
        iptables_service = service name do
          action :nothing
        end
      end
      iptables_service
    end

    def lookup_or_create_rulesfile(name)
      begin
        iptables_file = Chef.run_context.resource_collection.find(file: name)
      rescue
        iptables_file = file "/etc/iptables/#{name}" do
          action :nothing
        end
      end
      iptables_file
    end
  end
end
