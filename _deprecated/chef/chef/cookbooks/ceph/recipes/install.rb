# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Ceph Cookbook - Install Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs Ceph prerequisites, cephadm, and configures system requirements.
# -------------------------------------------------------------------------------

# --- Install Required Packages ---

package %w(curl python3 python3-pip docker.io chrony gnupg wget lvm2)

# --------------------------------------------------------------------
# Enable & Start Docker
# --------------------------------------------------------------------

service 'docker' do
  action [:enable, :start]
end

# --------------------------------------------------------------------
# Enable & Start Time Sync (Critical for Ceph)
# --------------------------------------------------------------------

service 'chronyd' do
  action [:enable, :start]
end

# --------------------------------------------------------------------
# Download & Install Ceph Release Key
# --------------------------------------------------------------------

execute 'install-ceph-release-key' do
  command "wget -q -O- 'https://download.ceph.com/keys/release.asc' | gpg --dearmor -o /etc/apt/trusted.gpg.d/cephadm.gpg"
  not_if  { ::File.exist?('/etc/apt/trusted.gpg.d/cephadm.gpg') }
  notifies :update, 'apt_update[update-after-ceph-repo]', :immediately
end

# --------------------------------------------------------------------
# Add Ceph Repository
# --------------------------------------------------------------------

ceph_release = node['ceph']['release']

file '/etc/apt/sources.list.d/ceph.list' do
  content "deb https://download.ceph.com/debian-#{ceph_release}/ bookworm main\n"
  mode    '0644'
  action  :create
  notifies :update, 'apt_update[update-after-ceph-repo]', :immediately
end

# --------------------------------------------------------------------
# Update Package Cache
# --------------------------------------------------------------------

apt_update 'update-after-ceph-repo' do
  action :nothing
end

# --------------------------------------------------------------------
# Install cephadm
# --------------------------------------------------------------------

package 'cephadm' do
  action :install
end

# --------------------------------------------------------------------
# Verify Installation
# --------------------------------------------------------------------

log 'ceph-install-complete' do
  message 'Ceph prerequisites and cephadm installed successfully'
  level   :info
end
