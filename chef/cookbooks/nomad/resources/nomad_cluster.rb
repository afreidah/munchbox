# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_cluster
# Purpose:: Start service, wait for Consul (optional), bootstrap ACL once.
# --------------------------------------------------------------------

property :bind_addr,        String, default: lazy { node['ipaddress'] }
property :wait_for_consul,  [true, false], default: true
property :consul_address, String, default: lazy { "#{node['ipaddress']}:8500" }
property :acl_enabled,      [true, false], default: true
property :bootstrap_this,   [true, false], default: false # set true on exactly one server

default_action :converge

# --- Name of resource for Nomad cluster initialization ---
provides :nomad_cluster
unified_mode true

action :converge do
  # Optionally wait for Consul to be ready before starting Nomad
  ruby_block 'wait-consul' do
    block do
      ok = NomadCookbook::Helper.consul_ready_http?(new_resource.consul_address, timeout: 60)
      raise "Consul at #{new_resource.consul_address} not ready after 60s" unless ok
    end
    only_if { new_resource.wait_for_consul }
  end

  service 'nomad' do
    action [:enable, :start]
  end

  return unless new_resource.acl_enabled && new_resource.bootstrap_this

  flag = NomadCookbook::Helper.acl_bootstrap_flag
  execute 'nomad-acl-bootstrap' do
    command 'nomad acl bootstrap -json > /root/nomad_acl_bootstrap.json'
    environment('NOMAD_ADDR' => "http://#{new_resource.bind_addr}:4646")
    sensitive true
    retries 3
    retry_delay 5
    not_if { ::File.exist?(flag) }
  end

  ruby_block 'mark-acl-bootstrapped' do
    block do
      ::File.write(flag, Time.now.utc.to_s)
      ::File.chmod(0600, flag)
    end
    not_if { ::File.exist?(flag) }
    notifies :restart, 'service[nomad]', :delayed
  end
end
