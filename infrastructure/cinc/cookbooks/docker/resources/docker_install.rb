# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
# Resource:: docker_install
#
# Adds the upstream Docker apt repo, installs docker-ce + cli +
# containerd + compose plugin, and enables docker.service. Optionally
# adds one or more users (default 'nomad') to the docker group so they can
# drive docker.sock without root, restarting the dependent service so it
# picks up the new GID.
#
# Arch is detected at converge time from node['kernel']['machine']
# (aarch64 -> arm64, x86_64 -> amd64).
# -------------------------------------------------------------------------------

unified_mode true

provides :docker_install

property :packages,             Array,                default: %w(docker-ce docker-ce-cli containerd.io docker-compose-plugin)
property :remove_packages,      Array,                default: %w(docker-buildx)
property :prereq_packages,      Array,                default: %w(apt-transport-https ca-certificates curl gnupg lsb-release)
# --- key_url + repo_uri default to nil; resolved per-platform inside the action so we don't ship one debian/ubuntu URL the user has to remember to override. ---
property :key_url,              [String, NilClass]
property :repo_uri,             [String, NilClass]
property :repo_component,       String, default: 'stable'
property :add_user_to_group,    [String, Array, NilClass], default: %w(nomad)
# --- Service to restart when the docker group changes membership; needed because already-running processes don't pick up new GIDs. nil to skip. ---
property :dependent_service,    [String, NilClass], default: 'nomad'

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Add upstream repo, install docker-ce, enable + start, group nomad
# -------------------------------------------------------------------------------

action :install do
  munchbox_base_apt_lock_wait 'docker_install_prereqs'

  apt_package new_resource.prereq_packages do
    action :install
  end

  # --- Drop docker-buildx (conflicts with docker-buildx-plugin from the upstream repo). ---
  apt_package new_resource.remove_packages do
    action :remove
    ignore_failure true
  end

  # --- Resolve arch + platform + lsb_release at converge time so the line matches the running OS. ---
  arch     = node['kernel']['machine'] == 'aarch64' ? 'arm64' : 'amd64'
  # --- Codename from /etc/os-release rather than node['lsb']['codename'] -- ohai's lsb fact is nil on greenfield nodes that don't yet have the lsb-release package installed at compile time. ---
  release  = ::File.read('/etc/os-release')[/^VERSION_CODENAME=(\S+)$/, 1] || node['lsb']&.dig('codename')
  platform = node['platform'] # 'ubuntu' or 'debian'

  # --- Docker has separate apt paths per distro; codename only matches the matching distro tree. ---
  uri = new_resource.repo_uri || "https://download.docker.com/linux/#{platform}"
  key = new_resource.key_url  || "https://download.docker.com/linux/#{platform}/gpg"

  apt_repository 'docker' do
    uri          uri
    distribution release
    components   [new_resource.repo_component]
    arch         arch
    key          key
    action       :add
  end

  munchbox_base_apt_lock_wait 'docker_install_packages'

  apt_package new_resource.packages do
    action :install
    notifies :restart, 'service[docker]', :delayed
  end

  service 'docker' do
    action %i(enable start)
  end

  # --- Add the runtime user(s) to the docker group; notify the dependent service only on actual membership change so we don't restart nomad on every chef-client run. ---
  docker_users = Array(new_resource.add_user_to_group)
  unless docker_users.empty?
    group 'docker' do
      action :create
      append true
      members docker_users
      notifies :restart, "service[#{new_resource.dependent_service}]", :delayed if new_resource.dependent_service
    end

    service new_resource.dependent_service do
      action :nothing
    end if new_resource.dependent_service
  end
end
