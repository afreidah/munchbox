# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  libraries/openbao_cluster.rb — OpenBao Cluster Management Library
#
#  Class-level helpers for managing OpenBao cluster lifecycle:
#    - Initialization (bao operator init)
#    - Unsealing (bao operator unseal)
#    - Raft join / membership helpers
# ------------------------------------------------------------------------------

require 'uri'
require 'json'
require 'time'
require 'resolv'
require 'openssl'
require 'net/http'
require 'fileutils'
require 'chef/mixin/shell_out'

# --- Require helper modules ---
require_relative 'shell_helpers'
require_relative 'address_helpers'

module OpenBao
  # ------------------------------------------------------------------------------
  #  OpenBao::Cluster
  #
  #  Provides class-level helpers for managing the lifecycle of an OpenBao cluster.
  #  Responsibilities include:
  #    - Initialization and unsealing
  #    - Raft cluster join/leave operations
  #    - TLS and address helpers
  #    - Status and health checks
  #  All methods are designed for use in Chef recipes and infrastructure automation.
  # ------------------------------------------------------------------------------

  class Cluster
    # --- Extend helper modules for shell commands, addresses, and certs ---
    extend OpenBao::ShellHelpers
    extend OpenBao::AddressHelpers
    extend OpenBao::Certs

    class << self
      attr_reader :json_file
    end

    # --- Defaults & paths ---
    @json_file = '/etc/openbao/init.json'

    # -----------------------------------------------------------------------------
    # init! — Runs `bao operator init`, writes output JSON, returns parsed keys
    #
    # Bootstrap flow:
    #   1) Probe local HTTPS via loopback (accept 501/503 etc.) TLS verify off.
    #   2) Run init with BAO_ADDR pointing at this node's FQDN (steady-state addr).
    #   3) Persist JSON to output_path.
    # -----------------------------------------------------------------------------

    def self.init!(output_path: @json_file, init_writer: nil)
      return read_init_file(output_path) if ::File.exist?(output_path)

      # --- Wait for local leader to be ready ---
      wait_for_leader!(
        leader: local_probe_addr,
        acceptable_codes: [501, 503, 200, 429, 472],
        tls_skip_verify: true,
        timeout: 120
      )

      # --- Run bao operator init command ---
      cmd = shell_out!(
        'bao operator init -format=json',
        env: shell_env(addr: this_node_addr)
      )

      # --- Get JSON output from command ---
      json_str = cmd.stdout.to_s
      # --- Validate the JSON output and exit status ---
      validate_init_json!(json_str, cmd.exitstatus)

      # --- Ensure output directory exists ---
      ::FileUtils.mkdir_p(::File.dirname(output_path))

      # --- Write JSON output to file ---
      writer = init_writer || ::File.method(:write).to_proc
      writer.call(output_path, json_str)

      # --- Parse and return the JSON output ---
      parse_init_json(json_str)
    end

    # -----------------------------------------------------------------------------
    # after_init_unseal! — Skip manual unseal when auto-unseal (KMS) is enabled
    # -----------------------------------------------------------------------------

    def self.after_init_unseal!(enable_auto_unseal:, unseal_keys:)
      return true if enable_auto_unseal
      unseal!(keys: unseal_keys)
    end

    # -----------------------------------------------------------------------------
    # unseal! — Apply unseal key shares until sealed==false
    # -----------------------------------------------------------------------------

    def self.unseal!(keys:)
      raise 'No unseal keys provided' if keys.nil? || keys.empty?

      # --- Iterate over each unseal key and apply it ---
      keys.each do |key|
        out = shell_out!(
          "bao operator unseal -format=json #{key}",
          env: shell_env(addr: this_node_addr)
        )
        # --- Stop if the cluster is unsealed ---
        break unless JSON.parse(out.stdout)['sealed']
      end

      # --- Raise error if still sealed after all keys applied or return true ---
      raise 'OpenBao is still sealed after unseal attempt' if bao_status[:sealed]
      true
    end

    # -----------------------------------------------------------------------------
    # join! — Join this node to the raft cluster using either:
    #   * a direct leader URL, or
    #
    # Selects FQDN when DNS works, else IP with SNI & TLS-skip.
    # -----------------------------------------------------------------------------

    def self.join!(
      leader: nil,
      hint: nil,
      tls_skip_verify: nil,
      enable_auto_unseal: false
    )
      # --- Wait for unseal if auto-unseal is enabled ---
      wait_for_unseal! if enable_auto_unseal

      # --- Determine target leader from hint or direct leader URL ---
      target =
        if hint.is_a?(Hash)
          leader_target_from_hint(hint)
        elsif leader.to_s.strip != ''
          { url: leader, tls_skip_verify: !!tls_skip_verify, sni: nil }
        else
          raise 'Leader address or hint hash is required for raft join'
        end

      # --- Wait for the leader node to be available ---
      wait_for_leader!(
        leader: target[:url],
        acceptable_codes: [200],
        tls_skip_verify: target[:tls_skip_verify],
        leader_sni: target[:sni],
        timeout: 60
      )

      # --- Prepare shell environment for join command ---
      env = shell_env(
        addr: target[:url],
        skip_verify: target[:tls_skip_verify],
        sni: target[:sni]
      )

      # --- Run the raft join command ---
      cmd = shell_out!(
        "bao operator raft join #{target[:url]}",
        env: env
      )
      return true if cmd.exitstatus.zero?

      # --- Check if already in cluster based on output ---
      out     = [cmd.stdout, cmd.stderr].join("\n")
      already = already_in_cluster?(out)
      return true if already

      # --- Raise error if join failed and not already in cluster ---
      raise "Raft join failed:\n#{out}"
    end

    # -----------------------------------------------------------------------------
    # leave_cluster! — Ask this node to leave the raft cluster
    # -----------------------------------------------------------------------------

    def self.leave_cluster!
      shell_out!('bao operator raft leave')
    end

    # -----------------------------------------------------------------------------
    # wait_for_leader! — Poll /v1/sys/health until HTTP code is acceptable
    #
    # Supports optional SNI & TLS-skip for IP-based probes.
    # -----------------------------------------------------------------------------

    def self.wait_for_leader!(
      leader:,
      acceptable_codes:,
      timeout: 60,
      interval: 2,
      tls_skip_verify: false,
      leader_sni: nil
    )
      # --- Build SSL options for HTTP request ---
      uri = URI("#{leader}/v1/sys/health?standbyok=true&perfstandbyok=true")
      opts = build_http_ssl_options(uri, tls_skip_verify: tls_skip_verify, leader_sni: leader_sni)

      # --- Poll the leader health endpoint until acceptable code is returned ---
      poll_http_until(
        uri: uri,
        headers: opts[:headers],
        use_ssl: opts[:use_ssl],
        verify_mode: opts[:verify_mode],
        cert_store: opts[:cert_store],
        hostname: opts[:hostname],
        timeout: timeout,
        interval: interval
      ) do |resp|
        acceptable_codes.include?(resp.code.to_i)
      end

    # --- Raise error if leader did not reach acceptable state in time ---
    rescue RuntimeError => e
      msg = "Leader did not reach acceptable state at #{leader} within #{timeout}s; " \
            "wanted #{acceptable_codes.inspect}"
      msg << ", last_error=#{e.class}: #{e.message}"
      raise msg
    end

    # -----------------------------------------------------------------------------
    # bao_status — Quick JSON status of local node
    # -----------------------------------------------------------------------------

    def self.bao_status
      out = shell_out!(
        'bao status -format=json',
        env: shell_env(addr: this_node_addr)
      )
      j = JSON.parse(out.stdout)
      { sealed: j['sealed'], standby: j['standby'], ha_enabled: j['ha_enabled'] }
    end

    # -----------------------------------------------------------------------------
    # wait_for_unseal! — Poll /v1/sys/seal-status until KMS auto-unseal finishes
    # -----------------------------------------------------------------------------

    def self.wait_for_unseal!(
      timeout: 120,
      interval: 5
    )
      # --- Build SSL options for HTTP request ---
      uri = URI("#{this_node_addr}/v1/sys/seal-status")
      opts = build_http_ssl_options(uri, tls_skip_verify: true)

      # --- Poll the seal-status endpoint until unsealed ---
      poll_http_until(
        uri: uri,
        headers: opts[:headers],
        use_ssl: opts[:use_ssl],
        verify_mode: opts[:verify_mode],
        cert_store: opts[:cert_store],
        hostname: opts[:hostname],
        timeout: timeout,
        interval: interval
      ) do |resp|
        body = JSON.parse(resp.body)
        body['sealed'] == false
      end

    # --- Raise error if unseal did not complete in time ---
    rescue RuntimeError
      raise "Timed out waiting for KMS auto-unseal after #{timeout}s"
    end

    # -----------------------------------------------------------------------------
    # DNS helpers
    # -----------------------------------------------------------------------------

    def self.dns_resolves?(fqdn)
      Resolv.getaddress(fqdn)
      true
    rescue Resolv::ResolvError, SocketError
      false
    end

    # -----------------------------------------------------------------------------
    # leader_target_from_hint — choose FQDN or IP+SNI based on DNS reachability
    # -----------------------------------------------------------------------------

    def self.leader_target_from_hint(h)
      # --- Extract FQDN, FQDN URL, and IP URL from hint hash ---
      fqdn     = h['leader_fqdn'].to_s
      fqdn_url = h['leader_url'].to_s
      ip_url   = h['leader_ip_url'].to_s

      # --- Prefer FQDN if DNS resolves ---
      if fqdn != '' && dns_resolves?(fqdn)
        { url: fqdn_url, tls_skip_verify: false, sni: nil }

      # --- Use IP with SNI if FQDN present but DNS fails ---
      elsif ip_url != '' && fqdn != ''
        { url: ip_url, tls_skip_verify: true, sni: fqdn }

      # --- Use FQDN URL with TLS skip if only URL is present ---
      elsif fqdn_url != ''
        { url: fqdn_url, tls_skip_verify: true, sni: fqdn.empty? ? nil : fqdn }

      # --- Raise error if hint is invalid ---
      else
        raise "Invalid leader hint: #{h.inspect}"
      end
    end

    # -----------------------------------------------------------------------------
    # poll_http_until — Polls an HTTP endpoint until a condition is met
    # # Parameters:
    # #   - uri: URI object for the HTTP endpoint
    # #   - headers: Hash of HTTP headers to include in the request
    # # #   - use_ssl: Boolean indicating whether to use SSL/TLS
    # # #   - verify_mode: OpenSSL::SSL::VerifyMode for SSL verification
    # # #   - cert_store: OpenSSL::X509::Store for custom certificate store
    # # #   - hostname: String for SNI hostname (if applicable)
    # # #   - timeout: Maximum time to wait for the condition to be met
    # # #   - interval: Time interval between polling attempts
    # # #   - condition: Block that takes the HTTP response and returns true/false
    # # # Returns true if the condition is met within the timeout, otherwise raises an error
    # # -----------------------------------------------------------------------------

    def self.poll_http_until(uri:, headers: {}, use_ssl: false, verify_mode: nil, cert_store: nil, hostname: nil, timeout:, interval:, &condition)
      # --- Calculate polling deadline based on timeout ---
      deadline = Time.now + timeout
      last_err = nil

      # --- Poll until deadline is reached ---
      while Time.now < deadline
        begin
          # --- Set up HTTP connection with SSL and options ---
          http = Net::HTTP.new(uri.host, uri.port)
          http.open_timeout = 5
          http.read_timeout = 5
          http.use_ssl = use_ssl
          http.verify_mode = verify_mode if verify_mode
          http.cert_store = cert_store if cert_store
          http.hostname = hostname if hostname && http.respond_to?(:hostname=)

          # --- Make HTTP GET request ---
          resp = http.get(uri.request_uri, headers)
          return true if condition.call(resp)

        # --- Store last error if request fails ---
        rescue StandardError => e
          last_err = e
        end

        sleep interval
      end

      # --- Raise error if polling timed out ---
      raise "HTTP polling timed out for #{uri} (last error: #{last_err})"
    end

    # -----------------------------------------------------------------------------
    # already_in_cluster? — Checks if the output indicates the node is already in
    # raft cluster
    # -----------------------------------------------------------------------------

    def self.already_in_cluster?(output)
      output =~ /
        already\ (?:a|part\ of\ the)\ raft\ cluster |
        peer\ already\ exists |
        node\ with\ ID\ .*\ already\ exists
      /ix
    end

    # ---------------------------------------------------------------------------
    # Ensures the /etc/hosts entry for the given IP and FQDN exists.
    # ---------------------------------------------------------------------------

    def self.ensure_hosts_entry(ip:, fqdn:)
      # --- Extract host from FQDN and prepare hosts line ---
      host = fqdn.split('.').first
      line = "#{ip} #{fqdn} #{host}"
      file = '/etc/hosts'
      content = ::File.read(file)

      # --- Append entry if FQDN not already present in /etc/hosts ---
      unless content.include?(fqdn)
        ::File.open(file, 'a') { |f| f.puts(line) }
      end
    end

    # --- Read and parse initialization file as JSON ---
    def self.read_init_file(path)
      raw  = ::File.read(path)
      json = ::JSON.parse(raw)
      { unseal_keys: json['unseal_keys_b64'], root_token: json['root_token'] }
    end

    def self.validate_init_json!(json_str, exitstatus)
      if json_str.strip.empty?
        raise "bao operator init produced no JSON on stdout (exitstatus=#{exitstatus})"
      end
    end

    # --- Parse JSON string and extract unseal keys and root token ---
    def self.parse_init_json(json_str)
      parsed = ::JSON.parse(json_str)
      { unseal_keys: parsed['unseal_keys_b64'], root_token: parsed['root_token'] }
    end
  end
end
