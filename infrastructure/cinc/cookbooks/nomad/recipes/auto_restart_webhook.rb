# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
# Recipe:: auto_restart_webhook
#
# Thin wrapper around nomad_auto_restart_webhook custom resource. Opt-in:
# include only on the node(s) that should run the AlertManager receiver
# (stabler today). Every property is sourced from
# node[:nomad][:auto_restart_webhook] so per-fleet / per-node attrs can
# override anything without re-implementing the resource.
# -------------------------------------------------------------------------------

w     = node[cookbook]['auto_restart_webhook']
paths = w['vault_paths']

nomad_auto_restart_webhook 'baseline' do
  service_name        w['service_name']
  service_description w['service_description']
  user                w['user']
  group               w['group']

  port                w['port']
  bind_address        w['bind_address']
  cooldown_seconds    w['cooldown_seconds']
  cooldown_dir        w['cooldown_dir']
  log_file            w['log_file']

  python_bin          w['python_bin']
  script_path         w['script_path']

  after_units         w['after_units'].to_a
  wants_units         w['wants_units'].to_a
  restart_policy      w['restart_policy']
  restart_sec         w['restart_sec']

  nomad_addr          w['nomad_addr']
  nomad_cacert        w['nomad_cacert']
  nomad_client_cert   w['nomad_client_cert']
  nomad_client_key    w['nomad_client_key']

  consul_service_file w['consul_service_file']
  consul_service_name w['consul_service_name']
  consul_service_tags w['consul_service_tags'].to_a
  consul_check_path   w['consul_check_path']
  consul_check_interval w['consul_check_interval']
  consul_check_timeout  w['consul_check_timeout']
  consul_user         w['consul_user']
  consul_group        w['consul_group']

  stale_paths         w['stale_paths'].to_a
  # --- attribute override wins (kitchen / break-glass); otherwise lazy vault_fetch at converge time ---
  nomad_token(lazy { w['nomad_token'] || vault_fetch(paths['nomad_token']['path'], paths['nomad_token']['field']) })
end
