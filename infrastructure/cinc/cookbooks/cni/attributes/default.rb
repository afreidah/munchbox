# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cni / Attributes: default
# -------------------------------------------------------------------------------

cookbook = 'cni'

default[cookbook]['install'] = {
  version:     '1.4.0',
  install_dir: '/opt/cni/bin',
  release_url: 'https://github.com/containernetworking/plugins/releases/download',
}
