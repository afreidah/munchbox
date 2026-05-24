# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: wireguard
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs WireGuard + manages one or more interfaces with their peer
# configuration. Multi-interface aware (oracle nodes run wg1; future
# home-ingress wg0 plugs in via the same shape). Server vs client
# differences (ListenPort, per-peer Endpoint, PersistentKeepalive) are
# handled by the same `wireguard_interface` resource via optional
# properties + a single ERB template.
# -------------------------------------------------------------------------------

name             'wireguard'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures WireGuard, multi-interface aware'
version          '0.8.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'

supports 'debian'
supports 'ubuntu'
