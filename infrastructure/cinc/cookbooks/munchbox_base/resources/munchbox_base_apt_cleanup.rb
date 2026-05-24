# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_apt_cleanup
#
# Runs `apt-get autoremove --purge` and `apt-get clean` to drop unused
# packages (notably old kernel images) and the downloaded .deb cache.
# Both commands are internally idempotent -- safe to fire on every
# chef-client converge.
#
# Properties:
#   autoremove   - Run `apt-get autoremove`. Default true.
#   purge        - Pass --purge to autoremove (drops config files for
#                  removed packages). Default true.
#   clean_cache  - Run `apt-get clean` (wipes /var/cache/apt/archives).
#                  Default true.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_apt_cleanup

property :autoremove,  [true, false], default: true
property :purge,       [true, false], default: true
property :clean_cache, [true, false], default: true

default_action :run

# -------------------------------------------------------------------------------
# Action :run  --  Wait for dpkg lock, then autoremove + clean
# -------------------------------------------------------------------------------

action :run do
  # --- Block until unattended-upgrades / other apt run releases the lock. ---
  munchbox_base_apt_lock_wait "apt_cleanup-#{new_resource.name}"

  if new_resource.autoremove
    purge_flag = new_resource.purge ? ' --purge' : ''
    execute "apt-get autoremove#{purge_flag} -y" do
      command "apt-get autoremove#{purge_flag} -y"
      environment 'DEBIAN_FRONTEND' => 'noninteractive'
    end
  end

  if new_resource.clean_cache
    execute 'apt-get clean' do
      command 'apt-get clean'
    end
  end
end
