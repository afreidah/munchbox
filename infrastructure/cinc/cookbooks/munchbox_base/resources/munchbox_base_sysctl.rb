# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_sysctl
#
# Renders a sysctl drop-in from a Hash of {key => value} pairs and
# reloads it. Generic so future cluster-wide kernel tweaks land here
# without a new recipe per knob.
#
# Properties:
#   path     - Drop-in path. Default /etc/sysctl.d/99-munchbox.conf.
#   settings - Hash of sysctl key/value pairs. Required, non-empty.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_sysctl

property :path,     String, default: '/etc/sysctl.d/99-munchbox.conf'
property :settings, Hash,   required: true,
                            callbacks: { 'must be non-empty' => ->(h) { !h.empty? } }

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure
# -------------------------------------------------------------------------------

action :configure do
  body  = ['# Managed by chef (munchbox_base::sysctl) -- do not edit by hand.']
  new_resource.settings.sort.each { |k, v| body << "#{k} = #{v}" }

  file new_resource.path do
    content  body.join("\n") + "\n"
    owner    'root'
    group    'root'
    mode     '0644'
    notifies :run, 'execute[reload munchbox sysctl]', :immediately
  end

  execute 'reload munchbox sysctl' do
    command "sysctl -p #{new_resource.path}"
    action  :nothing
  end
end
