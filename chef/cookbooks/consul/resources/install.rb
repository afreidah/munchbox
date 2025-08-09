# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  Resource: consul_install — Installs Consul binary or package, user, group, dirs
# ------------------------------------------------------------------------------

unified_mode true

property :version,        String, name_property: true
property :install_method, String, required: true
property :user,           String, required: true
property :group,          String, required: true
property :data_dir,       String, required: true
property :config_dir,     String, required: true
property :install_dir,    String, required: true
property :checksum,       [String, nil]

# ------------------------------------------------------------------------------
#  ACTION: :install
#
#    Installs Consul binary or package, creates user, group, and required dirs.
# ------------------------------------------------------------------------------

action :install do
  # --- Map kernel arch to HashiCorp archive label using helper ---
  machine      = node['kernel']['machine']
  archive_arch = ConsulCookbook.archive_arch(machine)

  consul_binary = ::File.join(new_resource.install_dir, 'consul')

  case new_resource.install_method
  when 'binary'
    # --- Install unzip for extracting Consul binary ---
    package 'unzip' do
      action :install
    end

    archive_url  = ConsulCookbook.archive_url(new_resource.version, archive_arch)
    archive_path = ::File.join(Chef::Config[:file_cache_path], "consul_#{new_resource.version}.zip")

    # --- Download Consul binary archive ---
    remote_file archive_path do
      source   archive_url
      checksum new_resource.checksum if new_resource.checksum
      action   :create
      not_if   { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(new_resource.version) }
    end

    # --- Ensure install directory exists ---
    directory new_resource.install_dir do
      mode      '0755'
      recursive true
    end

    # --- Unzip Consul binary ---
    execute 'unzip_consul' do
      command "unzip -o #{archive_path} -d #{new_resource.install_dir}"
      not_if  { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(new_resource.version) }
    end

    # --- Set permissions on Consul binary ---
    file consul_binary do
      mode '0755'
    end

  when 'package'
    # --- Install Consul via package manager ---
    package 'consul' do
      version new_resource.version
      action  :install
      not_if  { ::File.exist?(consul_binary) && `#{consul_binary} version`.include?(new_resource.version) }
    end

  else
    Chef::Log.error("Unknown consul install_method '#{new_resource.install_method}'")
  end

  # ----------------------------------------------------------------------------
  #  Create Consul User & Group
  # ----------------------------------------------------------------------------

  group new_resource.group do
    system true
    action :create
    not_if { new_resource.group == 'root' }
  end

  user new_resource.user do
    system true
    shell  '/usr/sbin/nologin'
    gid    new_resource.group
    home   new_resource.data_dir
    manage_home false
    action :create
    not_if { new_resource.user == 'root' }
  end

  # ----------------------------------------------------------------------------
  #  Create Consul Directories
  # ----------------------------------------------------------------------------

  [new_resource.data_dir, new_resource.config_dir].each do |dir|
    directory dir do
      owner     new_resource.user
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end
end

# ------------------------------------------------------------------------------
#  ACTION: :delete
#
#    Removes Consul binary, user, group, and all managed directories.
# ------------------------------------------------------------------------------

action :delete do
  consul_binary = ::File.join(new_resource.install_dir, 'consul')

  file consul_binary do
    action :delete
    only_if { ::File.exist?(consul_binary) }
  end

  [new_resource.data_dir, new_resource.config_dir].each do |dir|
    directory dir do
      recursive true
      action :delete
      only_if { ::File.directory?(dir) }
    end
  end

  user new_resource.user do
    action :remove
    only_if { new_resource.user != 'root' }
  end

  group new_resource.group do
    action :remove
    only_if { new_resource.group != 'root' }
  end
end
