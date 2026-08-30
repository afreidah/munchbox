# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Resource:: vault_install
#
# Installs the vault binary from HashiCorp's release archive (vault is
# both server + agent + cli, same binary). Also lays down the system
# user/group + standard directory layout if they don't already exist.
#
# Restarts the service on a version change, via the shared
# munchbox_lib_hashicorp_install. Safe to automate because the seal is
# OCI KMS -- a node comes back unsealed on its own. This used to be
# skipped deliberately when vault was shamir-sealed, which meant the
# binary swapped under a running vault and the process kept serving the
# old version until someone restarted it by hand.
#
# Still a planned event: converge one node at a time and
# `vault operator step-down` before promoting the active one.
#
# Properties:
#   version    - vault version (e.g. '1.15.4'); used to build the
#                download URL + detect drift via `vault version`.
#   bin_path   - Where to install the binary (default /usr/local/bin/vault).
#   user/group - System user/group vault runs as.
#   config_dir - /etc/vault.d (holds vault.hcl + tls/).
#   data_dir   - Per-node data dir (unused on consul-storage configs;
#                still created so a later raft-storage migration has a
#                target without another cookbook change).
#   tls_dir    - Where vault-cert-manager drops vault server certs.
# -------------------------------------------------------------------------------

unified_mode true

provides :vault_install

property :version,    String, required: true
property :bin_path,   String, default: '/usr/local/bin/vault'
property :user,       String, default: 'vault'
property :group,      String, default: 'vault'
property :config_dir, String, default: '/etc/vault.d'
property :data_dir,   String, default: '/opt/vault/data'
property :tls_dir,    String, default: '/etc/vault.d/tls'

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Ensure user/group/dirs, install binary only on drift
# -------------------------------------------------------------------------------

action :install do
  group new_resource.group do
    system true
  end

  user new_resource.user do
    group new_resource.group
    system true
    shell '/bin/false'
    home new_resource.data_dir
    manage_home false
  end

  # --- vault server uses consul as storage backend; it needs to read /etc/consul.d/tls/{consul.crt,consul.key,ca-chain.crt} which are consul:consul:0640 in a 0750 dir. Add vault to the consul group so it can traverse + read. consul cookbook always runs before vault cookbook in the vault-server roles, so the consul group is guaranteed to exist by this point. ---
  group 'consul' do
    members ['vault']
    append true
    action :modify
    only_if do
      begin
                ::Etc.getgrnam('consul')
      rescue
        false
              end
    end
  end

  # --- dirs (vault:vault 0750, matching what ansible left) + release-zip install
  #     + drift-only restart, shared with consul/nomad.
  #
  #     The restart is safe to automate because the seal is OCI KMS, so a node
  #     comes back unsealed on its own -- the old shamir rationale for skipping
  #     it no longer applies, and without it the binary swaps under a running
  #     vault and the process keeps serving the previous version indefinitely.
  #     Still converge one node at a time: restarting the active node forces a
  #     failover, so `vault operator step-down` before promoting it. ---
  munchbox_lib_hashicorp_install 'vault' do
    version  new_resource.version
    bin_path new_resource.bin_path
    dirs     [new_resource.config_dir, new_resource.data_dir, new_resource.tls_dir]
    owner    new_resource.user
    group    new_resource.group
  end
end

# -------------------------------------------------------------------------------
# Action :remove  --  Remove binary only; never touches data dirs or service.
# -------------------------------------------------------------------------------

action :remove do
  file new_resource.bin_path do
    action :delete
  end
end
