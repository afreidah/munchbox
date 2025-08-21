# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  _test_cluster.rb — Local, single-host Consul 3-node cluster for testing
#
#  Spins up consul@1, consul@2, consul@3 on 127.0.0.1 with unique ports.
#  Perfect for CI/Kitchen: no Docker DNS, no cross-container networking.
#  NOTE: Every instance gets its own non-overlapping port range (step=10)
#        to avoid bind collisions between raft/serf/http/dns ports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Include Firewall Recipe
# ------------------------------------------------------------------------------

include_recipe 'consul::firewall'

# ------------------------------------------------------------------------------
#  Install Consul (binary or package, user/group, directories)
# ------------------------------------------------------------------------------

consul_install 'consul' do
  version        node['consul']['version']
  install_method node['consul']['install_method']
  user           node['consul']['user']
  group          node['consul']['group']
  data_dir       node['consul']['data_dir']
  config_dir     node['consul']['config_dir']
  install_dir    node['consul']['install_dir']
  checksum       node['consul']['checksum'] if node['consul'].key?('checksum')
end

# --- Settings ---------------------------------------------------------------

install_dir = node['consul']['install_dir'] || '/usr/local/bin'
consul_bin  = ::File.join(install_dir, 'consul')

# Non-overlapping port blocks per instance (step of 10 avoids collisions)
# inst 1: 8300..8304, http 8500, dns 8600
# inst 2: 8310..8314, http 8510, dns 8610
# inst 3: 8320..8324, http 8520, dns 8620
base = {
  '1' => 0,
  '2' => 10,
  '3' => 20,
}

dc        = node['consul']['datacenter'] || 'kitchen'
log_level = (node['consul']['log_level'] || 'INFO').upcase

encrypt = begin
  bag = node.dig('consul', 'databag_name') || 'consul'
  itm = node.dig('consul', 'databag_item') || 'gossip'
  obj = data_bag_item(bag, itm)
  (obj['encrypt'] || obj['serf_key'] || obj['key']).to_s.strip
          rescue StandardError
            ''
end

# ------------------------------------------------------------------------------
#  systemd template unit (consul@.service)
# ------------------------------------------------------------------------------

systemd_unit 'consul@.service' do
  content(<<~UNIT)
    [Unit]
    Description=Consul Agent Instance %i
    Documentation=https://www.consul.io/
    After=network-online.target
    Wants=network-online.target

    [Service]
    User=root
    Group=root
    ExecStart=#{consul_bin} agent -config-dir=/etc/consul.d/%i
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    Restart=on-failure
    RestartSec=2
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
  UNIT
  action [:create]
end

# ------------------------------------------------------------------------------
#  Per-instance config dirs, data dirs, and configs
# ------------------------------------------------------------------------------

base.each do |inst, off|
  cfg_dir  = "/etc/consul.d/#{inst}"
  data_dir = "/opt/consul-#{inst}"

  directory cfg_dir do
    mode '0750'
    recursive true
  end
  directory data_dir do
    mode '0750'
    recursive true
  end

  # Unique ports for this instance (no collisions across instances)
  ports = {
    'http' => 8500 + off,
    'dns' => 8600 + off,
    'raft' => 8300 + off, # server (raft)
    'lan' => 8301 + off,      # serf LAN tcp/udp
    'wan' => 8302 + off,      # serf WAN tcp/udp
  }

  bootstrap_expect = 3

  # Peers: use each peer's serf_lan port; exclude self
  retry_join = base.map { |_i, o| "127.0.0.1:#{8301 + o}" } - ["127.0.0.1:#{ports['lan']}"]

  template "#{cfg_dir}/consul.hcl" do
    mode      '0640'
    owner     'root'
    group     'root'
    sensitive true
    variables(
      datacenter: dc,
      node_name: "consul#{inst}",
      data_dir: data_dir,
      log_level: log_level,
      encrypt: encrypt,
      ports: ports,
      retry_join: retry_join,
      bootstrap_expect: bootstrap_expect
    )
    source 'consul-instance.hcl.erb'
  end

  service "consul@#{inst}" do
    action [:enable, :start]
    subscribes :restart, "template[#{cfg_dir}/consul.hcl]", :delayed
  end
end

# ------------------------------------------------------------------------------
#  Health gates
# ------------------------------------------------------------------------------

# Wait for the Serf LAN ports of instances 2 and 3 to be up (tcp)
ruby_block 'wait_for_serf_ports' do
  block do
    require 'socket'
    require 'timeout'

    targets = [
      ['127.0.0.1', 8301 + base['2']], # inst 2 serf_lan = 8311
      ['127.0.0.1', 8301 + base['3']], # inst 3 serf_lan = 8321
    ]

    deadline = Time.now + 300
    until Time.now > deadline
      all_up = targets.all? do |host, port|
        begin
          Timeout.timeout(1) do
            TCPSocket.new(host, port).close
            true
          end
        rescue StandardError
          false
        end
      end
      break if all_up
      sleep 2
    end

    missing = targets.reject do |host, port|
      begin
        Timeout.timeout(1) do
          TCPSocket.new(host, port).close
          true
        end
      rescue StandardError
        false
      end
    end
    raise "Serf ports not listening: #{missing.map { |h, p| "#{h}:#{p}" }.join(', ')}" unless missing.empty?
  end
  action :run
end

# Ask instance 1 to join instances 2 & 3 (idempotent if already joined)
execute 'join_consul_instances' do
  http1 = "http://127.0.0.1:#{8500 + base['1']}"      # inst 1 HTTP = 8500
  lan2  = 8301 + base['2']                            # inst 2 serf_lan = 8311
  lan3  = 8301 + base['3']                            # inst 3 serf_lan = 8321
  command %(CONSUL_HTTP_ADDR=#{http1} #{consul_bin} join 127.0.0.1:#{lan2} 127.0.0.1:#{lan3})
  retries 10
  retry_delay 3
end

# Wait for a Raft leader with 3 peers
ruby_block 'wait_for_raft_leader' do
  block do
    require 'net/http'
    require 'json'
    http_port = 8500 + base['1'] # inst 1 HTTP = 8500
    leader_uri = URI("http://127.0.0.1:#{http_port}/v1/status/leader")
    peers_uri  = URI("http://127.0.0.1:#{http_port}/v1/status/peers")
    deadline   = Time.now + 300

    leader = false
    peers  = 0
    until Time.now > deadline
      leader = !Net::HTTP.get(leader_uri).strip.delete('"').empty?
      peers  = begin
                 JSON.parse(Net::HTTP.get(peers_uri)).length
               rescue
                 0
               end
      break if leader && peers == 3
      sleep 2
    end

    raise "No leader or peers!=3 (peers=#{peers}, leader=#{leader}) after 300s" unless leader && peers == 3
  end
end
