# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault
# Resource:: vault_install
#
# Installs the vault binary from HashiCorp's release archive (vault is
# both server + agent + cli, same binary). Also lays down the system
# user/group + standard directory layout if they don't already exist.
#
# DOES NOT notify the vault service to restart on a version change.
# Vault servers are shamir-sealed (5 shares, threshold 3); an
# unattended restart leaves the daemon sealed and locks out tenants
# until an operator manually unseals it x3. Version bumps must be
# planned events: change the pin here, upload, then the operator
# `systemctl restart vault` + `vault operator unseal` x3 per node.
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
# arch detection (arm64 for Pi5; amd64 elsewhere); URL + SHA256SUMS come from
# the shared HashiCorp helpers
# -------------------------------------------------------------------------------

action_class do
  def arch
    MunchboxLibCookbook::Artifact.normalize_arch(node['kernel']['machine'])
  end
end

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

  # --- Config + data + tls dirs are vault:vault 0750; matches what ansible left. ---
  [new_resource.config_dir, new_resource.data_dir, new_resource.tls_dir].each do |d|
    directory d do
      owner     new_resource.user
      group     new_resource.group
      mode      '0750'
      recursive true
    end
  end

  version     = new_resource.version
  drift_guard = "test -x #{new_resource.bin_path} && #{new_resource.bin_path} version | grep -q 'Vault v#{version}'"

  # --- Download + SHA256SUMS-verify + extract, then restart so the new binary
  #     actually takes effect. The seal is OCI KMS, so a node comes back unsealed
  #     on its own -- the old shamir rationale for skipping this notify no longer
  #     applies. Without it the binary swaps under a running vault and the process
  #     keeps serving the previous version indefinitely.
  #
  #     Still converge one node at a time: restarting the active node forces a
  #     failover, so `vault operator step-down` before promoting it. ---
  munchbox_lib_artifact "vault #{version}" do
    source           MunchboxLibCookbook::Artifact.hashicorp_url('vault', version, arch)
    sums_url         MunchboxLibCookbook::Artifact.hashicorp_sums_url('vault', version)
    format           :zip
    bin_dir          ::File.dirname(new_resource.bin_path)
    not_if_installed drift_guard
    notifies         :restart, 'service[vault]', :delayed
  end

  # --- Shadow service declaration so the notify above resolves inside this resource's collection (unified_mode sandboxes notify lookups per-action). ---
  service 'vault' do
    action :nothing
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
