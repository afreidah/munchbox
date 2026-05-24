# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: install
# -------------------------------------------------------------------------------

nomad_install 'nomad' do
  version    node[cookbook]['install']['version']
  bin_path   node[cookbook]['install']['bin_path']
  user       node[cookbook]['install']['user']
  group      node[cookbook]['install']['group']
  config_dir node[cookbook]['install']['config_dir']
  data_dir   node[cookbook]['install']['data_dir']
  log_dir    node[cookbook]['install']['log_dir']
end
