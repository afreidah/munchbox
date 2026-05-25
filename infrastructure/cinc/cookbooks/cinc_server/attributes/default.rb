# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
# Attributes:: default
#
# Defaults for the cinc_server cookbook. Every entry is keyed under the
# cookbook's namespace via `node[cookbook]`, so renaming the cookbook is a
# one-line change in metadata.rb.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# cinc-server package
#
# cinc-server isn't published to a generic apt repo; the project ships .deb
# artefacts at downloads.cinc.sh. Pin a known-good version per node so
# upgrades are a deliberate attribute bump, not a silent moving target.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  version: '15.10.91',
  url: 'https://downloads.cinc.sh/files/stable/cinc-server/15.10.91/debian/12/cinc-server-core_15.10.91-1_amd64.deb',
  checksum: nil,
  package_name: 'cinc-server-core',
}

# -------------------------------------------------------------------------------
# chef-server.rb config
#
# `api_fqdn` is the one setting every install must override. Extra knobs go
# into `settings` and are rendered verbatim into chef-server.rb (so values
# need to be valid ruby literals -- quote strings, etc.).
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  api_fqdn: 'cinc-server.munchbox.cc',
  # --- Extra SAN entries (with `DNS:` or `IP:` prefix); api_fqdn is added automatically ---
  ssl_alt_names: [],
  settings: {
    "nginx['enable_non_ssl']" => 'true',
  },
}

# -------------------------------------------------------------------------------
# Initial org + admin user (cinc_server::bootstrap)
#
# Override these per-node (especially `password`) before running the
# bootstrap recipe. The captured admin private key is written to
# `key_path` -- pick a directory that's tight on perms and out of the
# repo, since this key has full server admin rights.
# -------------------------------------------------------------------------------

default[cookbook]['bootstrap'] = {
  org: {
    short_name: 'munchbox',
    full_name: 'Munchbox',
  },
  user: {
    username: 'alex',
    first_name: 'Alex',
    last_name: 'Freidah',
    email: 'alex.freidah@gmail.com',
    # --- nil by default; recipe lazy-fetches from Vault. Override to a literal string only for break-glass / kitchen runs. ---
    password: nil,
    key_path: '/etc/cinc-bootstrap/alex.pem',
  },
}

# -------------------------------------------------------------------------------
# Vault paths
#
# Bootstrap-time secrets. vault_agent::configure has gated on the token sink
# at /run/vault-agent/token by the time bootstrap converges (cinc_server_host
# role layers role[vault_agent] before the cinc_server recipes), so the
# lazy{} vault_fetch in bootstrap.rb is safe.
# -------------------------------------------------------------------------------

default[cookbook]['vault_paths'] = {
  admin_password: {
    path: 'secret/data/cinc-server/admin/alex',
    field: 'password',
  },
}
