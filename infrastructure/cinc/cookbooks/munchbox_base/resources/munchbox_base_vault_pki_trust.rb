# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_vault_pki_trust
#
# Pulls a Vault PKI mount's CA certificate and lands it at one or more
# destination paths. Before overwriting an existing different cert at any
# destination, the prior file is renamed to `<base>-<YYYYMMDD><ext>` so a
# rollback is available if the new CA breaks dependents (nomad, docker pulls).
#
# Properties:
#   mount             - Vault PKI mount name (default 'pki_int').
#   destinations      - Array of absolute paths to receive the CA cert (required).
#   trigger_ca_update - When true, any change to a path under
#                       /usr/local/share/ca-certificates/ kicks off
#                       update-ca-certificates and (optional) docker reload.
#                       Default true.
#   reload_docker     - On system-trust change, restart docker so it picks up
#                       the refreshed bundle. Default true. Set false for
#                       nodes that don't have docker running.
#   backup_dir        - Directory to move rotated-out certs into. Must NOT be
#                       /usr/local/share/ca-certificates/ (update-ca-certificates
#                       would keep trusting the old cert). Default
#                       /var/backups/vault-pki.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_vault_pki_trust

property :mount,             String,        default: 'pki_int'
property :destinations,      Array,         required: true
property :trigger_ca_update, [true, false], default: true
property :reload_docker,     [true, false], default: true
property :backup_dir,        String,        default: '/var/backups/vault-pki'
property :stale_paths,       Array,         default: []

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Fetch CA, rotate old files, write new
# -------------------------------------------------------------------------------

action :configure do
  # --- sweep ansible-era stale paths (file or dir) ---
  new_resource.stale_paths.each do |path|
    if ::File.directory?(path) && !::File.symlink?(path)
      directory path do
        recursive true
        action :delete
      end
    else
      file path do
        action :delete
      end
    end
  end

  ca_pem        = vault_pki_ca(new_resource.mount)
  ca_pem        = "#{ca_pem}\n" unless ca_pem.end_with?("\n")
  system_change = false

  new_resource.destinations.each do |dest|
    parent = ::File.dirname(dest)
    directory parent do
      owner 'root'
      group 'root'
      mode  '0755'
      not_if { ::Dir.exist?(parent) }
    end

    # --- Normalize for compare so a missing trailing newline (or extra one) doesn't trigger a needless rotation on every converge. ---
    existing = ::File.exist?(dest) ? ::File.read(dest) : nil
    next if existing && existing.strip == ca_pem.strip

    # --- Back up the prior cert into backup_dir (NOT alongside the live cert) so update-ca-certificates doesn't keep trusting the rotated-out CA. Rollback is still a single `mv`. ---
    if existing
      directory new_resource.backup_dir do
        owner 'root'
        group 'root'
        mode  '0755'
        recursive true
        not_if { ::Dir.exist?(new_resource.backup_dir) }
      end

      stamp    = ::Time.now.strftime('%Y%m%d')
      ext      = ::File.extname(dest)
      basename = ::File.basename(dest, ext)
      backup   = ::File.join(new_resource.backup_dir, "#{basename}-#{stamp}#{ext}")
      ::File.rename(dest, backup) unless ::File.exist?(backup)
      Chef::Log.info("munchbox_base_vault_pki_trust: rotated #{dest} -> #{backup}")
    end

    file dest do
      content  ca_pem
      owner    'root'
      group    'root'
      mode     '0644'
      sensitive true
    end

    system_change = true if dest.start_with?('/usr/local/share/ca-certificates/')
  end

  if system_change && new_resource.trigger_ca_update
    execute "update-ca-certificates (vault-pki #{new_resource.mount})" do
      command 'update-ca-certificates'
      action  :run
    end

    if new_resource.reload_docker
      service 'docker' do
        action :restart
      end
    end
  end
end
