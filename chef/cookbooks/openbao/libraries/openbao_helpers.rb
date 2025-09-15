# frozen_string_literal: true

# ------------------------------------------------------------------------------
# Cookbook:: openbao
# Library:: helpers
#
# Provides helper functions for the vpn cookbook include:
#   - dynamic cookbook namespace key resolution for portable attribute access,
# ------------------------------------------------------------------------------

module OpenBao
  module Helpers
    # ---------------------------------------------------------------------------
    #  Use cookbook_name as the namespace key for all attribute hashes:
    #     node[cookbook_name]['key'] instead of node['vpn']['key']
    #
    #    Memoization is used so that parse_cookbook_name is only called once.
    # ---------------------------------------------------------------------------

    def cookbook_name
      @cookbook_name ||= parse_cookbook_name
    end

    # ---------------------------------------------------------------------------
    #  Parse cookbook name from metadata.rb or Policyfile.rb
    # ---------------------------------------------------------------------------

    def parse_cookbook_name
      cookbook_dir    = File.dirname(__FILE__)
      metadata_path   = File.join(cookbook_dir, '..', 'metadata.rb')
      policyfile_path = File.join(cookbook_dir, '..', 'Policyfile.rb')

      # --- Check both files for a line defining the cookbook name ---
      [metadata_path, policyfile_path].each do |path|
        next unless File.exist?(path)

        File.foreach(path) do |line|
          # --- Match lines like: name 'cookbook_name' or name "cookbook_name" ---
          return ::Regexp.last_match(1) if line =~ /^name\s+['"]([^'"]+)['"]/
        end
      end
      # --- Return nil if no name is found ---
      nil
    end

    # ---------------------------------------------------------------------------
    # Checks if the current environment is Test Kitchen
    # ----------------------------------------------------------------------------

    def kitchen?
      ENV['TEST_KITCHEN'] == '1'
    end

    # ---------------------------------------------------------------------------
    # Returns opeenbao service name
    # ----------------------------------------------------------------------------

    def service_name
      node[cookbook_name]['svc_name']
    end

    # ---------------------------------------------------------------------------
    # Returns path to the ssl certs
    # ----------------------------------------------------------------------------

    def ssl_cert_directory
      node[cookbook_name]['ssl']['target_path']
    end

    # ---------------------------------------------------------------------------
    # returns correct path to debian package download
    # ----------------------------------------------------------------------------

    def self.download_path(version)
      deb_name = "bao_#{version}_linux_amd64.deb"
      "https://github.com/openbao/openbao/releases/download/v#{version}/#{deb_name}"
    end

    # ---------------------------------------------------------------------------
    #  Returns a unique sentinel file path for a given token.
    #  The filename includes a visual portion (20 chars of token without spaces)
    #  for human identification, plus a 12-character hash for uniquen`ess.
    # ---------------------------------------------------------------------------

    def sentinel_for(token)
      visual = token.to_s.gsub(/[^a-za-z0-9._-]/, '')[0, 20]
      hash = Digest::SHA256.hexdigest(token.to_s)[0, 12]
      ::File.join(node['global']['sentinel_dir'], "initialized_#{visual}_#{hash}")
    end

    # ---------------------------------------------------------------------------
    # Returns whether global sensitive value is true or false
    # ----------------------------------------------------------------------------

    def is_sensitive?
      value = node['global']['sensitive']
      value.nil? || value
    end

    # ---------------------------------------------------------------------------
    #  Checks if the SHA256 of a file has changed since the last check.
    #     If changed, writes the new SHA256 to a .sha256 file next to the original.
    #     file - String Path to the file to check.
    #     Result is a Boolean: true if SHA256 changed, false otherwise.
    # ---------------------------------------------------------------------------

    def new_sha256?(file)
      sha_file = "#{file}.sha256"
      old_sha  = File.exist?(sha_file) ? File.read(sha_file) : ''
      sha256   = Digest::SHA256.file(file).hexdigest

      # --- If the SHA256 has changed, write the new value to the .sha256 file ---
      if sha256 != old_sha
        ::File.write(sha_file, sha256)
        return true
      end
      false
    end
  end
end

# --- Include the helpers into all Chef DSLs ---
Chef::DSL::Universal.include(OpenBao::Helpers)
Chef::Log.debug('OpenBao::Helpers module loaded and universally included')
