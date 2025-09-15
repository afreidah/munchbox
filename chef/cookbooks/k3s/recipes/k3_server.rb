# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  k3s_server.rb — Install and Configure k3s (Debian, single-node server)
#
#  This recipe:
#    1) Installs minimal prerequisites (curl/CA)
#    2) Installs k3s (server) via official script
#    3) Ensures kubectl is available (symlink to k3s if missing)
#    4) Writes ~/.kube/config from /etc/rancher/k3s/k3s.yaml with secure perms
#    5) Ensures k3s service is enabled and running
#
#  Notes:
#    • Firewall is handled separately in recipes/firewall.rb.
#    • All tunables/paths expected in attributes/default.rb.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Config (single handle to attributes)
# ------------------------------------------------------------------------------
config = node['k3s']

# ------------------------------------------------------------------------------
# Packages (minimal prerequisites)
# ------------------------------------------------------------------------------
Array(config['install_packages']).each do |pkg|
  apt_package pkg do
    action :install
  end
end

# ------------------------------------------------------------------------------
# Install k3s (server) — official script; guarded for idempotency
# ------------------------------------------------------------------------------
execute 'install_k3s' do
  command 'curl -sfL https://get.k3s.io | sh -'
  environment lazy {
    env = { 'INSTALL_K3S_EXEC' => config['install_exec'] }
    env['INSTALL_K3S_VERSION'] = config['version'] if config['version']
    env['INSTALL_K3S_CHANNEL'] = config['channel'] if config['channel']
    env
  }
  not_if { ::File.exist?('/usr/local/bin/k3s') }
end

# ------------------------------------------------------------------------------
# Service — ensure running after install
# ------------------------------------------------------------------------------
service 'k3s' do
  action [:enable, :start]
  supports status: true, restart: true
  only_if { ::File.exist?('/etc/systemd/system/k3s.service') || ::File.exist?('/lib/systemd/system/k3s.service') }
end

# ------------------------------------------------------------------------------
# kubectl — ensure available (symlink to k3s if standalone kubectl missing)
# ------------------------------------------------------------------------------
link '/usr/local/bin/kubectl' do
  to '/usr/local/bin/k3s'
  only_if { ::File.exist?('/usr/local/bin/k3s') }
  not_if  { ::File.exist?('/usr/local/bin/kubectl') }
end

# ------------------------------------------------------------------------------
# kubeconfig — create ~/.kube and write config from server kubeconfig
# ------------------------------------------------------------------------------
directory config['kube_dir'] do
  owner     config['user']
  group     config['user']
  mode      '0700'
  recursive true
end

file config['kube_config'] do
  owner     config['user']
  group     config['user']
  mode      '0600'
  sensitive true
  content   lazy {
    ::File.exist?(config['server_kube']) ? ::File.read(config['server_kube']) : ''
  }
  only_if { ::File.exist?(config['server_kube']) }
end

# ------------------------------------------------------------------------------
# Post-Install Note — log if the server kubeconfig is not yet available
# ------------------------------------------------------------------------------
ruby_block 'log_missing_k3s_yaml' do
  block do
    Chef::Log.warn("#{config['server_kube']} not found; kubeconfig not written. Re-run once k3s is fully initialized.")
  end
  not_if { ::File.exist?(config['server_kube']) }
end

