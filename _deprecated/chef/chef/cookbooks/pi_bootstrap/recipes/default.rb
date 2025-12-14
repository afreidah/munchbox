# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Pi Bootstrap Cookbook - Default Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Bootstraps a Raspberry Pi with hostname, package installation, and Docker.
# -------------------------------------------------------------------------------

# --- Set Variables ---

host = node['set_fqdn']

# --- Log Detected IP Address ---

ruby_block 'log my ipaddress' do
  block do
    ip = node['ipaddress']
    Chef::Log.info("My IP address is #{ip}")
  end
end

# --- Set Hostname Based on IP Address ---

template '/etc/hostname' do
  source 'hostname.erb'
  variables(hostname: host)
  notifies :run, 'execute[hostnamectl-set]', :immediately
end

execute 'hostnamectl-set' do
  command lazy { "hostnamectl hostname #{host}" }
  action :nothing
end

# --- Update /etc/hosts with New Hostname ---

ruby_block 'update_etc_hosts' do
  block do
    hosts = ::File.read('/etc/hosts').lines.reject { |l| l =~ /127\.0\.1\.1/ }
    hosts << "127.0.1.1   #{host}\n"
    ::File.write('/etc/hosts', hosts.join)
  end
  only_if { ::File.exist?('/etc/hosts') }
end

# --- Install Required Packages ---

package node['pi_bootstrap']['packages'] do
  action :install
end

# --- Enable and Start Docker Service ---

service 'docker' do
  action [:enable, :start]
  only_if { systemd? }
end


# --- Install nvm and Node.js (as root) ---

bash 'install_nvm_and_node' do
  code <<-CODE
    set -e
    export NVM_DIR="$HOME/.nvm"

    # Install NVM if not already present
    if [ ! -f "$NVM_DIR/nvm.sh" ]; then
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # Load NVM for this session
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

    # Install and use latest Node.js
    nvm install --lts
    nvm alias default 'lts/*'
  CODE
  environment({ 'HOME' => '/root', 'USER' => 'root' })
  not_if { ::File.exist?('/root/.nvm/nvm.sh') }
end

# --- Install Node.js using nvm ---

bash 'install_node' do
  code <<-CODE
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    nvm install node # Install the latest version of Node.js
  CODE
end
