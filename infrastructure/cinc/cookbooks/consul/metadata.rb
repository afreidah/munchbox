# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs HashiCorp Consul on a node in either server or client mode
# (toggled by node attribute). Drops /etc/consul.d/consul.hcl + the
# systemd unit and brings the agent up. TLS certs (/etc/consul.d/tls/)
# are owned out-of-band by vault-cert-manager.
# -------------------------------------------------------------------------------

name             'consul'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures HashiCorp Consul (server or client mode)'
version          '0.5.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
