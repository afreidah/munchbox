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
  config_path = ::File.join(new_resource.config_dir, 'consul.hcl')

  # --- Resolve data bag source (supports plain or encrypted) ---
  #     Defaults:
  #       - bag:  "consul"
  #       - item: "gossip"
  #       - key field names checked in order: "encrypt", "serf_key", "key"
  #     Toggle encryption with node['consul']['encrypted_data_bag'] (true/false).
  ruby_block 'load_consul_serf_key_from_databag' do
    block do
      bag_name       = node.dig('consul', 'databag_name') || 'consul'
      item_name      = node.dig('consul', 'databag_item') || 'gossip'
      encrypted_bag  = !!node.dig('consul', 'encrypted_data_bag')

      if encrypted_bag
      end
      item = data_bag_item(bag_name, item_name)

      key = item['encrypt'] || item['serf_key'] || item['key']
      if key.to_s.strip.empty?
        raise "Consul gossip key not found in data bag '#{bag_name}/#{item_name}'. " \
              "Expected one of: 'encrypt', 'serf_key', or 'key'."
      end

      node.run_state['consul_serf_key'] = key.strip
    end
    action :run
  end

  # --- Render Consul HCL Config ---
  template config_path do
    mode      '0640'
    source    'consul.hcl.erb'
    owner     new_resource.user
    group     new_resource.group
    sensitive true
    variables(
      serf_key: lazy { node.run_state['consul_serf_key'] },
      retry_join: node['consul']['retry_join']
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
