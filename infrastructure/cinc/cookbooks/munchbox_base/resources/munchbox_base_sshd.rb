# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_sshd
#
# Owns /etc/ssh/sshd_config end-to-end. The file is fully templated so we
# don't have to fight first-occurrence-wins precedence against whatever the
# upstream package or base image dropped in. The Vault SSH CA wiring is a
# separate action so it can run in a separate recipe after vault-agent has
# populated /run/vault-agent/token -- otherwise vault_fetch races vault-agent
# on greenfield nodes.
#
# Actions:
#   :configure     -- Template sshd_config + enable+start sshd.
#                     Safe to run at any point; no Vault dependency.
#   :configure_ca  -- Wire up Vault SSH CA: trusted user CA pubkey,
#                     per-user authorized_principals files, the
#                     HostCertificate / TrustedUserCAKeys /
#                     AuthorizedPrincipalsFile directives as a sshd_config.d
#                     drop-in, and a break-glass pubkey in authorized_keys.
#                     Must run AFTER vault_agent::configure (needs the
#                     /run/vault-agent/token sink).
#
# Properties:
#   settings    -- Hash of snake_case keys -> values rendered as
#                  PascalCase sshd directives in the main sshd_config
#                  template (e.g. permit_root_login -> PermitRootLogin).
#                  Required by :configure.
#   ca_settings -- Hash of SSH-CA knobs (paths, principals, break-glass
#                  config). Consumed by :configure_ca.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_sshd

property :settings,    Hash, default: {}
property :ca_settings, Hash, default: {}

default_action :configure

# -------------------------------------------------------------------------------
# Action :configure  --  Template sshd_config + enable/start sshd (no Vault)
# -------------------------------------------------------------------------------

action :configure do
  template '/etc/ssh/sshd_config' do
    source 'sshd_config.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    variables(settings: new_resource.settings)
    notifies :restart, 'service[ssh]', :delayed
  end

  service 'ssh' do
    action %i(enable start)
  end
end

# -------------------------------------------------------------------------------
# Action :configure_ca  --  Wire SSH CA (requires vault-agent token sink)
# -------------------------------------------------------------------------------

action :configure_ca do
  ca = new_resource.ca_settings

  trusted_user_ca = ca['trusted_user_ca_path']  || '/etc/ssh/trusted-user-ca-keys.pem'
  host_cert       = ca['host_cert_path']        || '/etc/ssh/ssh_host_ed25519_key-cert.pub'
  principals_dir  = ca['principals_dir']        || '/etc/ssh/authorized_principals'
  principals      = ca['principals']            || { 'root' => ['root'] }
  client_path     = ca['client_signer_vault_path']  || 'ssh-client-signer/config/ca'
  client_field    = ca['client_signer_vault_field'] || 'public_key'
  host_path       = ca['host_signer_vault_path']    || 'ssh-host-signer/config/ca'
  host_field      = ca['host_signer_vault_field']   || 'public_key'

  service 'ssh' do
    action :nothing
  end

  # --- Trusted user CA pubkey (sshd's TrustedUserCAKeys reads this) ---
  file trusted_user_ca do
    owner 'root'
    group 'root'
    mode  '0644'
    content lazy { "#{vault_fetch(client_path, client_field).chomp}\n" }
    notifies :restart, 'service[ssh]', :delayed
  end

  # --- @cert-authority entry in /root/.ssh/known_hosts so root's outbound SSH trusts host certs across the fleet. ---
  directory '/root/.ssh' do
    owner 'root'
    group 'root'
    mode  '0700'
  end

  ruby_block 'pin host CA in /root/.ssh/known_hosts' do
    block do
      host_ca  = vault_fetch(host_path, host_field).chomp
      line     = "@cert-authority * #{host_ca}"
      path     = '/root/.ssh/known_hosts'
      existing = ::File.exist?(path) ? ::File.read(path) : ''
      new_content = if existing.match?(/^@cert-authority \*/)
                      existing.sub(/^@cert-authority \*.*$/, line)
                    else
                      existing.empty? ? "#{line}\n" : "#{existing.chomp}\n#{line}\n"
                    end
      next if new_content == existing

      ::File.write(path, new_content)
      ::File.chmod(0o644, path)
    end
  end

  # --- authorized_principals dir + per-user files ---
  directory principals_dir do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  principals.each do |user, principal_list|
    file "#{principals_dir}/#{user}" do
      owner 'root'
      group 'root'
      mode  '0644'
      content "#{Array(principal_list).join("\n")}\n"
    end
  end

  # --- sshd drop-in: hooks up the three directives. main sshd_config template ends with `Include /etc/ssh/sshd_config.d/*.conf` so this gets picked up after the hardening directives. ---
  file '/etc/ssh/sshd_config.d/10-munchbox-ssh-ca.conf' do
    owner 'root'
    group 'root'
    mode  '0644'
    content <<~CONF
      # Managed by chef (munchbox_base::sshd_ca) -- do not edit by hand.
      HostCertificate #{host_cert}
      TrustedUserCAKeys #{trusted_user_ca}
      AuthorizedPrincipalsFile #{principals_dir}/%u
    CONF
    notifies :restart, 'service[ssh]', :delayed
  end

  next unless ca['manage_break_glass']

  bg_path  = ca['break_glass_vault_path']  || 'secret/data/ssh/break-glass'
  bg_field = ca['break_glass_vault_field'] || 'public_key'
  bg_users = ca['break_glass_users']       || ['root']

  bg_users.each do |user|
    home = user == 'root' ? '/root' : "/home/#{user}"

    directory "#{home}/.ssh" do
      owner user
      group user
      mode  '0700'
      not_if { user != 'root' && !::Dir.exist?(home) }
    end

    ruby_block "break-glass key in #{user} authorized_keys" do
      block do
        key      = vault_fetch(bg_path, bg_field).chomp
        path     = "#{home}/.ssh/authorized_keys"
        existing = ::File.exist?(path) ? ::File.read(path) : ''
        next if existing.include?(key)

        ::File.open(path, 'a') do |f|
          f.write("\n") unless existing.end_with?("\n") || existing.empty?
          f.puts(key)
        end
        ::File.chmod(0o600, path)
        ::FileUtils.chown(user, user, path)
      end
      only_if { ::Dir.exist?(home) }
    end
  end
end
