# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Recipe:: watchdog
#
# Wrapper -- installs + configures oracle-watchdog. Work lives in
# oracle_watchdog.
# -------------------------------------------------------------------------------

w = node[cookbook]['watchdog']

oracle_watchdog 'baseline' do
  package_name         w['package_name']
  config_dir           w['config_dir']
  consul_addr          w['consul_addr']
  metrics_port         w['metrics_port']
  vault_path           w['vault_path']
  vault_field          w['vault_field']
  consul_service_file  w['consul_service_file']
end
