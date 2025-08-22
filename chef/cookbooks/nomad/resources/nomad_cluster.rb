# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_cluster
# Purpose:: Start service (via notify), wait for Consul (optional),
#           bootstrap Nomad ACLs exactly once, and handle TLS-aware env.
# --------------------------------------------------------------------

property :bind_addr,           String, default: lazy { node['ipaddress'] }
property :wait_for_consul,     [true, false], default: true
property :consul_address,      String, default: lazy { "#{node['ipaddress']}:8500" }
property :consul_wait_timeout, Integer, default: 180 # seconds; ARM boards can take longer to settle
property :acl_enabled,         [true, false], default: true
property :bootstrap_this,      [true, false], default: false # set true on exactly one server

default_action :converge

# --- Name of resource for Nomad cluster initialization ---
provides :nomad_cluster
unified_mode true

action :converge do
  # Optionally wait for Consul to be ready before starting Nomad
  ruby_block 'wait-consul' do
    block do
      ok = NomadCookbook::Helper.consul_ready_http?(new_resource.consul_address,
                                                    timeout: new_resource.consul_wait_timeout)
      raise "Consul at #{new_resource.consul_address} not ready after #{new_resource.consul_wait_timeout}s" unless ok
    end
    only_if { new_resource.wait_for_consul }
  end

  # Define service resource so other resources can notify it (single source of truth for start/enable)
  service 'nomad' do
    action :nothing
  end

  # TLS-aware environment for CLI commands (works for HTTP or HTTPS)
  ruby_block 'build-nomad-env' do
    block do
      tls_enabled = node['nomad']['tls']['enabled']
      addr = "http#{tls_enabled ? 's' : ''}://#{new_resource.bind_addr}:4646"
      env = { 'NOMAD_ADDR' => addr }

      if tls_enabled
        env['NOMAD_CACERT'] = node['nomad']['tls']['ca_file'] if node['nomad']['tls']['ca_file']
        # If your API requires client auth, uncomment the following:
        # env['NOMAD_CLIENT_CERT'] = node['nomad']['tls']['cert_file']
        # env['NOMAD_CLIENT_KEY']  = node['nomad']['tls']['key_file']
        # Or, to skip verification (not recommended): env['NOMAD_SKIP_VERIFY'] = '1'
      end

      node.run_state['nomad_env'] = env
    end
  end

  return unless new_resource.acl_enabled && new_resource.bootstrap_this

  flag = NomadCookbook::Helper.acl_bootstrap_flag

  # Only bootstrap if not already done; pre-check avoids failing on already bootstrapped clusters
  execute 'nomad-acl-bootstrap' do
    command 'nomad acl bootstrap -json > /root/nomad_acl_bootstrap.json'
    environment(lazy { node.run_state['nomad_env'] || {} })
    sensitive true
    retries 3
    retry_delay 5
    not_if { ::File.exist?(flag) }
    not_if 'nomad acl info >/dev/null 2>&1'
  end

  ruby_block 'mark-acl-bootstrapped' do
    block do
      ::File.write(flag, Time.now.utc.to_s)
      ::File.chmod(0o600, flag)
    end
    not_if { ::File.exist?(flag) }
  end
end
