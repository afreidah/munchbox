# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: nomad
# Resource:: nomad_install
# Purpose:: Install/upgrade Nomad in an idempotent, arch‑aware way.
# --------------------------------------------------------------------

# --- Name of resource for Nomad cluster installation ---
provides :nomad_install
unified_mode true

property :version,      String,  required: true
property :bin_path,     String,  default: '/usr/local/bin'
property :checksums,    Hash,    default: {} # { '1.10.3' => { 'amd64' => 'sha256', 'arm64' => 'sha256' } }
property :install_user, String,  default: 'root'
property :install_group, String, default: 'root'

default_action :install

action :install do
  package 'unzip' # ensure unzip binary exists

  arch       = NomadCookbook::Helper.arch_for(node)
  ver        = new_resource.version
  zip_name   = "nomad_#{ver}_linux_#{arch}.zip"
  cache_file = ::File.join(Chef::Config[:file_cache_path], zip_name)
  url        = "https://releases.hashicorp.com/nomad/#{ver}/#{zip_name}"
  sha        = new_resource.checksums.dig(ver, arch)

  remote_file cache_file do
    source   url
    mode     '0644'
    checksum sha if sha
  end

  bash 'install-nomad' do
    code <<-EOH
      unzip -o #{cache_file} -d /tmp
      install -m 0755 /tmp/nomad #{new_resource.bin_path}/nomad
    EOH
    not_if { NomadCookbook::Helper.installed_version("#{new_resource.bin_path}/nomad") == "v#{ver}" }
  end
end
