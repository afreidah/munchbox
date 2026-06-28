# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Library:: artifact
#
# Generic, Chef-free primitives for verifying downloaded artifacts. Nothing here
# knows about consul, nomad, vault, or cinc -- the caller builds its own URL and
# tells the install resource how to validate it (a literal sha256, or a
# SHA256SUMS body + the filename to look up). These helpers are pure Ruby so
# they unit-test directly; the Chef wiring lives in the artifact_install
# resource that calls them.
# -------------------------------------------------------------------------------

require 'digest'

module MunchboxLibCookbook
  module Artifact
    class << self
      # --- Normalize Ohai's node['kernel']['machine'] to a common arch token ---
      def normalize_arch(machine)
        case machine
        when 'aarch64', 'arm64' then 'arm64'
        when 'x86_64', 'amd64'  then 'amd64'
        else
          raise "munchbox_lib: unsupported machine architecture #{machine.inspect}"
        end
      end

      # --- HashiCorp release archive URL; consul/nomad/vault all share this shape ---
      def hashicorp_url(product, version, arch)
        "https://releases.hashicorp.com/#{product}/#{version}/#{product}_#{version}_linux_#{arch}.zip"
      end

      # --- Matching SHA256SUMS body for that release (one file per arch listed) ---
      def hashicorp_sums_url(product, version)
        "https://releases.hashicorp.com/#{product}/#{version}/#{product}_#{version}_SHA256SUMS"
      end

      def file_sha256(path)
        Digest::SHA256.file(path).hexdigest
      end

      # --- Pull one file's sha out of a "<sha>  <filename>" SHA256SUMS body ---
      def sha256_for(sums_text, filename)
        sums_text.each_line do |line|
          sha, name = line.strip.split(/\s+/, 2)
          return sha.downcase if name && name == filename
        end
        raise "munchbox_lib: #{filename} not present in SHA256SUMS"
      end

      # --- The integrity gate: raise unless the file matches expected ---
      def verify!(path, expected)
        raise "munchbox_lib: no expected checksum supplied for #{path}" if expected.nil? || expected.empty?

        actual = file_sha256(path)
        return true if actual.casecmp?(expected)

        raise "munchbox_lib: checksum mismatch for #{path}: expected #{expected}, got #{actual}"
      end
    end
  end
end
