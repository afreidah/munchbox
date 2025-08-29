# frozen_string_literal: true

# -----------------------------------------------------------------------------
# Cookbook:: openbao
# Resource:: openbao_cluster
#
# Bare-metal init/unseal + optional peer join. No AWS, no S3.
# Chef 18-safe: avoid referencing new_resource inside ruby_block context.
# -----------------------------------------------------------------------------

unified_mode true
provides :openbao_cluster

require 'json'
require 'mixlib/shellout'

# --- Properties ---
property :api_addr,      String, default: 'https://127.0.0.1:8200'
property :tls_ca,        String, required: true          # CA trust for CLI
property :tls_cert,      String, required: true          # (server cert on disk; not used by CLI)
property :tls_key,       String, required: true          # (server key on disk; not used by CLI)

# Initialization
property :init_sentinel, String, default: '/var/lib/openbao/init.json'
property :key_shares,    Integer, default: 3
property :key_threshold, Integer, default: 2

# Optional: unseal keys provided out-of-band; otherwise read from sentinel
property :unseal_keys,   Array, default: []

# Optional: static peer list to join (e.g., ["https://host2:8200", "https://host3:8200"])
property :join_addrs,    Array, default: []

# Service name
property :service_name,  String, default: 'openbao'

# Helper lambdas that do NOT reference new_resource; pass explicit args.
def sh_out(cmd, env)
  c = Mixlib::ShellOut.new(cmd, env: env)
  c.run_command
  c
end

action :init do
  # Ensure service is up enough to answer status
  service new_resource.service_name do
    action %i[enable start]
  end

  env = {
    'VAULT_ADDR'   => new_resource.api_addr,
    'VAULT_CACERT' => new_resource.tls_ca,
  }
  sentinel      = new_resource.init_sentinel
  key_shares    = new_resource.key_shares
  key_threshold = new_resource.key_threshold

  ruby_block 'openbao-init' do
    block do
      initialized = false
      begin
        s = sh_out('bao status', env)
        initialized = (s.stdout =~ /Initialized\s+true/i) ? true : false
      rescue
        initialized = false
      end

      unless initialized || ::File.exist?(sentinel)
        cmd = sh_out("bao operator init -key-shares=#{key_shares} -key-threshold=#{key_threshold} -format=json", env)
        cmd.error!  # raise if non-zero
        ::FileUtils.mkdir_p(::File.dirname(sentinel))
        ::File.write(sentinel, cmd.stdout)
      end
    end
    sensitive true
  end
end

action :unseal do
  env           = { 'VAULT_ADDR' => new_resource.api_addr, 'VAULT_CACERT' => new_resource.tls_ca }
  sentinel      = new_resource.init_sentinel
  key_threshold = new_resource.key_threshold
  provided_keys = Array(new_resource.unseal_keys)

  ruby_block 'openbao-unseal' do
    block do
      sealed = true
      begin
        s = sh_out('bao status', env)
        sealed = (s.stdout =~ /Sealed\s+true/i) ? true : false
      rescue
        sealed = true
      end
      next unless sealed

      keys =
        if provided_keys.any?
          provided_keys
        elsif ::File.exist?(sentinel)
          json = ::JSON.parse(::File.read(sentinel))
          json['unseal_keys_hex'] || json['unseal_keys'] || []
        else
          []
        end

      keys.first(key_threshold).each do |k|
        sh_out("bao operator unseal #{k}", env).error!
      end
    end
    sensitive true
  end
end

action :join do
  env        = { 'VAULT_ADDR' => new_resource.api_addr, 'VAULT_CACERT' => new_resource.tls_ca }
  join_peers = Array(new_resource.join_addrs)

  # One execute per peer, tolerate "already joined" non-zero codes via returns
  join_peers.each do |peer|
    execute "bao-raft-join-#{peer}" do
      command "bao operator raft join #{peer}"
      environment env
      returns [0, 2] # allow 'already member' exit code
      # Avoid trying to join while sealed (best-effort check)
      not_if "bao status | grep -E 'Sealed\\s+true'", environment: env
    end
  end
end
