# frozen_string_literal: true

# -----------------------------------------------------------------------------
# Cookbook:: your_cookbook
# Resource:: certificate_installer
#
# Installs known cert/key/bundle files to a target directory using a predefined
# mapping and a centralized data bag (e.g., bdbo/ssl[edo.com]).
#
# Properties:
#   databag       - Data bag name (e.g., 'bdbo')
#   item          - Data bag item (e.g., 'ssl')
#   section       - Key inside the item (e.g., 'edo.com')
#   target_path   - Base path to write the files (e.g., /etc/bao/certs)
#
# Example:
#   certificate_installer 'install bao certs' do
#     databag 'bdbo'
#     item 'ssl'
#     section 'edo.com'
#     target_path '/etc/bao/certs'
#   end
# -----------------------------------------------------------------------------

unified_mode true

# --- Name of resource for Certificate installation ---
provides :certificate_installer

property :databag, String, required: true
property :item, String, required: true
property :section, String, required: true
property :target_path, String, required: true
property :owner, String, default: 'root'
property :group, String, default: 'root'

# --- Use shared CERT_MAP from OpenBao::Certs module ---
require_relative '../libraries/openbao_certs'
CERT_MAP = OpenBao::Certs::CERT_MAP

# ------------------------------------------------------------------------------
# Action: :install — Installs certificate files from CERT_MAP to target_path
# ------------------------------------------------------------------------------

action :install do
  ssl = data_bag_item(new_resource.databag, new_resource.item)

  CERT_MAP.each_value do |config|
    file ::File.join(new_resource.target_path, config['filename']) do
      owner   new_resource.owner
      group   new_resource.group
      mode    config['mode']
      content ssl[new_resource.section][config['content_key']]
    end
  end
end

# ------------------------------------------------------------------------------
# Action: :remove — Deletes all certificate files from target_path
# ------------------------------------------------------------------------------

action :remove do
  CERT_MAP.each_value do |config|
    file ::File.join(new_resource.target_path, config['filename']) do
      action :delete
    end
  end
end
