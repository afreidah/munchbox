# cookbooks/consul/recipes/agent_token.rb
#
# Ensures a Consul *agent token* exists, is set on the running agent,
# and is persisted in Consul's config so it survives restarts.
#
# Assumptions:
# - Management token is already written to /opt/consul/consul_mgmt.token
#   (e.g., by consul::management_token)
# - The Consul policy the agent token should use already exists
#   (defaults to "nomad-client", created by consul::acl_nomad)
#
# Idempotency:
# - Reuses /opt/consul/acl-tokens.json if present
# - Creates the token only once and then reuses it
# - Always (re)sets the agent token on the local agent with the mgmt token

require 'json'

mgmt_token_file   = '/opt/consul/consul_mgmt.token'
agent_tokens_file = '/opt/consul/acl-tokens.json'
persist_file      = '/etc/consul.d/tokens.hcl'
policy_name       = node['consul'] && node['consul']['agent_policy'] || 'nomad-client'
consul_http_addr  = node['consul'] && node['consul']['http_addr'] || 'http://127.0.0.1:8500'

# Make sure base dir exists with safe perms
directory ::File.dirname(mgmt_token_file) do
  owner 'root'
  group 'root'
  mode '0750'
end

# Ensure Consul service resource is known so we can notify it later
service 'consul' do
  action [:enable, :start]
  supports status: true, restart: true, reload: true
end

ruby_block 'ensure_consul_agent_token' do
  block do
    require 'net/http'
    require 'uri'

    def http_json(method, url, headers: {}, body: nil, expect: 200)
      uri = URI(url)
      req = case method
            when :get  then Net::HTTP::Get.new(uri)
            when :put  then Net::HTTP::Put.new(uri)
            when :post then Net::HTTP::Post.new(uri)
            when :del  then Net::HTTP::Delete.new(uri)
            else raise "Unsupported method #{method}"
            end
      headers.each { |k, v| req[k] = v }
      if body
        req['Content-Type'] = 'application/json'
        req.body = JSON.dump(body)
      end
      Net::HTTP.start(uri.hostname, uri.port) do |h|
        res = h.request(req)
        unless Array(expect).map(&:to_i).include?(res.code.to_i)
          raise "HTTP #{method.upcase} #{url} failed: #{res.code} #{res.body}"
        end
        res
      end
    end

    # 1) Read mgmt token
    unless ::File.exist?(%{#{mgmt_token_file}})
      raise "Consul management token not found at #{mgmt_token_file}. Run consul::management_token first."
    end
    mgmt = ::File.read(%{#{mgmt_token_file}}).strip
    raise 'Empty management token' if mgmt.empty?

    # 2) Load or create an agent token SecretID
    secret = nil
    if ::File.exist?(%{#{agent_tokens_file}})
      begin
        json = JSON.parse(::File.read(%{#{agent_tokens_file}}))
        secret = json['agent']
      rescue => e
        Chef::Log.warn("Failed parsing #{agent_tokens_file}: #{e}")
      end
    end

    if secret.to_s.empty?
      # Create a new token bound to the desired policy
      desc = "Agent token for #{node['hostname']}"
      Chef::Log.info("Creating Consul agent token with policy '#{policy_name}' (desc: #{desc})")
      res = http_json(
        :put,
        "#{consul_http_addr}/v1/acl/token",
        headers: { 'X-Consul-Token' => mgmt },
        body: {
          'Description' => desc,
          'Local'       => true,
          'Policies'    => [{ 'Name' => policy_name }]
        },
        expect: [200]
      )
      data = JSON.parse(res.body)
      secret = data['SecretID']
      raise 'Consul did not return SecretID for created token' if secret.to_s.empty?

      # Persist our record of the SecretID
      ::File.write(%{#{agent_tokens_file}}, JSON.dump({ 'agent' => secret }))
      ::File.chmod(0600, %{#{agent_tokens_file}})
    else
      Chef::Log.debug("Reusing existing Consul agent token from #{agent_tokens_file}")
    end

    # 3) Set the agent token on the running agent (requires mgmt token)
    Chef::Log.info('Setting agent token on local Consul agent')
    http_json(
      :put,
      "#{consul_http_addr}/v1/agent/token/agent",
      headers: { 'X-Consul-Token' => mgmt },
      body: { 'Token' => secret },
      expect: [200]
    )

    # Stash for the file resource below
    node.run_state['consul_agent_token_secret'] = secret
  end
  action :run
end

# 4) Persist across restarts in Consul config (safe perms)
file persist_file do
  owner 'root'
  group 'root'
  mode '0600'
  sensitive true
  content lazy {
    tok = node.run_state['consul_agent_token_secret']
    raise 'Missing agent token in run_state; ruby_block must run first' if tok.to_s.empty?
    <<~HCL
      acl {
        tokens {
          agent = "#{tok}"
        }
      }
    HCL
  }
  notifies :reload, 'service[consul]', :delayed
end

# 5) Quick verification (optional, logs only)
ruby_block 'verify_agent_token' do
  block do
    begin
      require 'json'
      secret = node.run_state['consul_agent_token_secret']
      uri = URI("#{consul_http_addr}/v1/agent/self")
      req = Net::HTTP::Get.new(uri)
      req['X-Consul-Token'] = secret
      res = Net::HTTP.start(uri.hostname, uri.port) { |h| h.request(req) }
      if res.code.to_i == 200
        name = JSON.parse(res.body).dig('Config', 'NodeName')
        Chef::Log.info("Consul agent token works; agent/self reports NodeName=#{name}")
      else
        Chef::Log.warn("agent/self with agent token returned #{res.code}: #{res.body}")
      end
    rescue => e
      Chef::Log.warn("Verification of agent token failed: #{e}")
    end
  end
  action :run
end
