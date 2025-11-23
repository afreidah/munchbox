# frozen_string_literal: true
# --------------------------------------------------------------------
# Cookbook:: ceph
# Recipe:: bootstrap
#
# Bootstraps Ceph cluster on the designated bootstrap node.
# Configures monitors, managers, and adds additional nodes.
# Assumes SSH keys are already configured between nodes.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Inputs / Defaults
# --------------------------------------------------------------------

bootstrap_node = node['ceph']['bootstrap_node']
current_node   = node['hostname']
cluster_nodes  = Array(node['ceph']['nodes'])

# --------------------------------------------------------------------
# Verify Bootstrap Node
# --------------------------------------------------------------------

return unless current_node == bootstrap_node

# --------------------------------------------------------------------
# Build Bootstrap Options (always use node['ipaddress'])
# --------------------------------------------------------------------

skip_monitoring = node.dig('ceph', 'skip_monitoring') ? true : false
skip_dashboard  = node.dig('ceph', 'skip_dashboard') ? true : false
mon_ip          = node['ipaddress']                    # single source of truth for MON bind IP
mon_network     = node.dig('ceph', 'mon_network')      # optional CIDR, e.g., "192.168.68.0/24"

raise "Ohai did not provide node['ipaddress']" if mon_ip.nil? || mon_ip.empty?

bootstrap_opts = []
bootstrap_opts << "--mon-ip #{mon_ip}"
if mon_network && !mon_network.empty?
  bootstrap_opts << "--mon-network #{mon_network}"
else
  bootstrap_opts << "--skip-mon-network"               # configure later if desired
end
bootstrap_opts << '--skip-monitoring-stack' if skip_monitoring
bootstrap_opts << '--skip-dashboard'        if skip_dashboard
bootstrap_opts << '--cleanup-on-failure'                     # remove partial state on error

# --------------------------------------------------------------------
# Bootstrap Ceph Cluster
# --------------------------------------------------------------------

execute 'bootstrap-ceph' do
  command "cephadm bootstrap #{bootstrap_opts.join(' ')}"
  # Idempotency: only skip if a MON is actually present on this host
  not_if  "cephadm ls 2>/dev/null | grep -q '\"name\": \"mon\\.'"
  timeout 600
end

# --------------------------------------------------------------------
# Install Ceph CLI Tools
# --------------------------------------------------------------------

execute 'install-ceph-common' do
  command 'cephadm install ceph-common'
  not_if { ::File.exist?('/usr/bin/ceph') }
end

# --------------------------------------------------------------------
# Wait for Cluster to be Ready
# --------------------------------------------------------------------

execute 'wait-for-ceph' do
  command     'ceph status'
  retries     10
  retry_delay 5
end

# --------------------------------------------------------------------
# Add Cluster Nodes
# --------------------------------------------------------------------

ruby_block 'add-cluster-nodes' do
  block do
    require 'open3'
    require 'json'

    cluster_nodes.each do |hostname|
      next if hostname == bootstrap_node

      # Check if node already added
      stdout, _stderr, status = Open3.capture3('ceph orch host ls --format json')
      hosts = JSON.parse(stdout) if status.success?

      unless hosts&.any? { |h| h['hostname'] == hostname }
        Chef::Log.info("Adding node #{hostname} to Ceph cluster")
        system("ceph orch host add #{hostname} #{hostname}")
        sleep 5
      end
    end
  end
  action :run
end

# --------------------------------------------------------------------
# Configure OSDs (Auto-Discovery)
# --------------------------------------------------------------------

auto_discover_osds = node.dig('ceph', 'auto_discover_osds') ? true : false

if auto_discover_osds
  execute 'add-osds' do
    command 'ceph orch apply osd --all-available-devices'
    not_if  "ceph osd tree | grep -q 'osd.'"
  end
end

# --------------------------------------------------------------------
# Wait for OSDs to be Created
# --------------------------------------------------------------------

execute 'wait-for-osds' do
  command     'sleep 10 && ceph osd tree'
  retries     10
  retry_delay 5
  only_if     'ceph status'
end

# --------------------------------------------------------------------
# Create Nomad Storage Pool
# --------------------------------------------------------------------

pool_name       = node['ceph']['pool']['name']
pool_pg_num     = node['ceph']['pool']['pg_num']
pool_size       = node['ceph']['pool']['size']
pool_min_size   = node['ceph']['pool']['min_size']

execute 'create-nomad-pool' do
  command "ceph osd pool create #{pool_name} #{pool_pg_num} #{pool_pg_num}"
  not_if  "ceph osd pool ls | grep -q '^#{pool_name}$'"
end

execute 'set-pool-size' do
  command "ceph osd pool set #{pool_name} size #{pool_size}"
  only_if "ceph osd pool ls | grep -q '^#{pool_name}$'"
end

execute 'set-pool-min-size' do
  command "ceph osd pool set #{pool_name} min_size #{pool_min_size}"
  only_if "ceph osd pool ls | grep -q '^#{pool_name}$'"
end

execute 'enable-rbd-application' do
  command "ceph osd pool application enable #{pool_name} rbd"
  not_if  "ceph osd pool application get #{pool_name} | grep -q rbd"
end

# --------------------------------------------------------------------
# Enable Prometheus Module
# --------------------------------------------------------------------

prometheus_enabled = node.dig('ceph', 'prometheus', 'enabled') ? true : false
prometheus_port    = node['ceph']['prometheus']['port']

if prometheus_enabled
  execute 'enable-prometheus-module' do
    command <<-EOH
      ceph mgr module enable prometheus
      ceph config set mgr mgr/prometheus/server_addr 0.0.0.0
      ceph config set mgr mgr/prometheus/server_port #{prometheus_port}
    EOH
    only_if 'ceph status'
  end
end

# --------------------------------------------------------------------
# Bootstrap Complete
# --------------------------------------------------------------------

log 'ceph-bootstrap-complete' do
  message 'Ceph cluster bootstrapped successfully with nomad-volumes pool'
  level   :info
end
