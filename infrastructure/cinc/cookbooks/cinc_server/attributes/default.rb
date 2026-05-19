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
  'version' => '15.10.91',
  'url' => 'https://downloads.cinc.sh/files/stable/cinc-server/15.10.91/debian/12/cinc-server-core_15.10.91-1_amd64.deb',
  'checksum' => nil,
}

# -------------------------------------------------------------------------------
# chef-server.rb config
#
# `api_fqdn` is the one setting every install must override. Extra knobs go
# into `settings` and are rendered verbatim into chef-server.rb (so values
# need to be valid ruby literals -- quote strings, etc.).
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  'api_fqdn' => 'cinc-server.local',
  'settings' => {
    "nginx['enable_non_ssl']" => 'true',
  },
}
