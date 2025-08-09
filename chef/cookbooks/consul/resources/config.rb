# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  Resource: consul_config — Renders Consul HCL configuration file
# ------------------------------------------------------------------------------

unified_mode true

property :config_dir,  String, required: true
property :install_dir, String, required: true
property :user,        String, required: true
property :group,       String, required: true

# ------------------------------------------------------------------------------
#  Action: :create — Renders Consul HCL configuration file
# ------------------------------------------------------------------------------

action :create do
  consul_binary = ::File.join(new_resource.install_dir, 'consul')
  config_path = ::File.join(new_resource.config_dir, 'consul.hcl')
  keyfile = ::File.join(new_resource.config_dir, 'serf.key')

  # --- Generate gossip encryption key if needed ---
  ruby_block 'generate_consul_serf_key' do
    block do
      unless ::File.exist?(keyfile)
        key = shell_out!("#{consul_binary} keygen").stdout.strip
        ::File.write(keyfile, key)
      end
    end
    action :run
    only_if { ::File.exist?(consul_binary) }
  end

  # --- Read key from file and set for template ---
  ruby_block 'read_consul_serf_key' do
    block do
      node.run_state['consul_serf_key'] = ::File.read(keyfile).strip
    end
    action :run
    only_if { ::File.exist?(keyfile) }
  end

  # --- Render Consul HCL Config ---
  template config_path do
    source    'consul.hcl.erb'
    owner     new_resource.user
    group     new_resource.group
    mode      '0640'
    sensitive true
    variables(
      serf_key: lazy { node.run_state['consul_serf_key'] }
    )
  end
end

# ------------------------------------------------------------------------------
#  Action: :delete — Removes Consul HCL configuration file
# ------------------------------------------------------------------------------

action :delete do
  config_path = ::File.join(new_resource.config_dir, 'consul.hcl')

  file config_path do
    action :delete
  end
end
