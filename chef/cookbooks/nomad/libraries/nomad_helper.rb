# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Library:: nomad_helper
# --------------------------------------------------------------------

require 'mixlib/shellout'
require 'json'

module NomadCookbook
  class Helper
    # --------------------------------------------------------------
    # Detect Nomad version by parsing `nomad version` first line.
    # Returns "vX.Y.Z" or nil.
    # --------------------------------------------------------------

    def self.installed_version(bin = '/usr/local/bin/nomad')
      return unless ::File.exist?(bin)
      cmd = Mixlib::ShellOut.new("#{bin} version")
      cmd.run_command
      cmd.error!
      cmd.stdout[/v\d+\.\d+\.\d+/]
    rescue StandardError
      nil
    end

    # --------------------------------------------------------------
    # Map kernel machine to Hashi arch token.
    # --------------------------------------------------------------

    def self.arch_for(node)
      case node['kernel']['machine']
      when 'x86_64', 'amd64' then 'amd64'
      when 'aarch64'         then 'arm64'
      when /armv(6|7|8)l|arm/ then 'arm'
      else node['kernel']['machine']
      end
    end

    # --------------------------------------------------------------
    # Simple HTTP check for Consul leader; blocks Nomad start until ready.
    # Returns true/false; safe for guards.
    # --------------------------------------------------------------

    def self.consul_ready_http?(addr_port = '127.0.0.1:8500', timeout: 60)
      require 'net/http'
      require 'uri'
      deadline = Time.now + timeout
      uri = URI("http://#{addr_port}/v1/status/leader")

      until Time.now > deadline
        begin
          res = Net::HTTP.get_response(uri)
          return true if res.is_a?(Net::HTTPSuccess) && res.body && res.body.strip != '""'
        rescue StandardError
          # ignore and retry
        end
        sleep 2
      end

      false
    end

    # --------------------------------------------------------------
    # Guard file path for one‑time ACL bootstrap.
    # --------------------------------------------------------------

    def self.acl_bootstrap_flag
      '/var/lib/nomad/.acl_bootstrapped'
    end
  end
end
