# frozen_string_literal: true

# ------------------------------------------------------------------------------
# Cookbook:: openbao
# Library:: certs
#
# Provides helper functions for certificate file mapping and path resolution.
#   - Centralized static map for cert/key/bundle files
#   - Utility for retrieving cert file info by key
# ------------------------------------------------------------------------------

module OpenBao
  module Certs
    # ---------------------------------------------------------------------------
    #  Static map of known certificate files and their attributes
    # ---------------------------------------------------------------------------

    CERT_MAP = {
      'server_cert' => { 'filename' => 'bao.crt', 'mode' => '0644', 'content_key' => 'cert' },
      'server_key'  => { 'filename' => 'bao.key', 'mode' => '0600', 'content_key' => 'key'  },
      'ca_bundle'   => { 'filename' => 'ca.crt',  'mode' => '0644', 'content_key' => 'ca'   }
    }.freeze

    # ---------------------------------------------------------------------------
    #  Returns cert file info hash for a given key and target path
    # ---------------------------------------------------------------------------

    def self.cert_info(key, target_path = '/etc/openbao/tls')
      config = CERT_MAP[key]
      return unless config

      {
        filename: config['filename'],
        content_key: config['content_key'],
        mode: config['mode'],
        path: ::File.join(target_path, config['filename']),
      }
    end

    # ---------------------------------------------------------------------------
    # Builds HTTP SSL options for OpenBao based on the URI and TLS settings
    # # @param uri [URI] The URI to build options for
    # # @param tls_skip_verify [Boolean] Whether to skip TLS verification
    # # @param leader_sni [String] Optional SNI hostname for the leader
    # # @return [Hash] A hash containing SSL options for HTTP requests
    #  ---------------------------------------------------------------------------

    def build_http_ssl_options(uri, tls_skip_verify: false, leader_sni: nil)
      use_ssl = uri.scheme == 'https'
      verify_mode = ssl_verify_mode(use_ssl, tls_skip_verify)
      cert_store = ssl_cert_store(use_ssl, tls_skip_verify)
      headers = ssl_headers(use_ssl, leader_sni)
      hostname = ssl_hostname(use_ssl, leader_sni)
      {
        headers: headers,
        use_ssl: use_ssl,
        verify_mode: verify_mode,
        cert_store: cert_store,
        hostname: hostname,
      }
    end

    private

    # ---------------------------------------------------------------------------
    # Determines the SSL verification mode based on use_ssl and tls_skip_verify
    # # @param use_ssl [Boolean] Whether SSL is being used
    # # # @param tls_skip_verify [Boolean] Whether to skip TLS verification
    # # # @return [OpenSSL::SSL::VerifyMode, nil] The verification mode or nil if not using SSL
    # ---------------------------------------------------------------------------

    def ssl_verify_mode(use_ssl, tls_skip_verify)
      return unless use_ssl

      tls_skip_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
    end

    # ---------------------------------------------------------------------------
    # Creates an OpenSSL certificate store for SSL verification
    # # @param use_ssl [Boolean] Whether SSL is being used
    # # # @param tls_skip_verify [Boolean] Whether to skip TLS verification
    # # # @return [OpenSSL::X509::Store, nil] The certificate store or nil if not using SSL
    # ---------------------------------------------------------------------------

    def ssl_cert_store(use_ssl, tls_skip_verify)
      return unless use_ssl && !tls_skip_verify

      store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
      store.add_file(CA_BUNDLE) if defined?(CA_BUNDLE) && ::File.exist?(CA_BUNDLE)
      store
    end

    # ---------------------------------------------------------------------------
    # Generates SSL headers for HTTP requests
    # # @param use_ssl [Boolean] Whether SSL is being used
    # # # @param leader_sni [String] Optional SNI hostname for the leader
    # # # @return [Hash] A hash containing SSL headers or an empty hash if not using SSL
    # ---------------------------------------------------------------------------
    def ssl_headers(use_ssl, leader_sni)
      return {} unless use_ssl && leader_sni.to_s != ''

      { 'Host' => leader_sni }
    end

    # ---------------------------------------------------------------------------
    # Determines the SSL hostname for SNI (Server Name Indication)
    # # # @param use_ssl [Boolean] Whether SSL is being used
    # # # @param leader_sni [String] Optional SNI hostname for the leader
    # # # @return [String, nil] The SNI hostname or nil if not using SSL or no SNI is provided
    # ---------------------------------------------------------------------------

    def ssl_hostname(use_ssl, leader_sni)
      use_ssl && leader_sni.to_s != '' ? leader_sni : nil
    end
  end
end

Chef::Log.debug('OpenBao::Certs module loaded')
