# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nomad
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs HashiCorp Nomad on a node in server, client, or combined mode
# (toggled by node attributes). Drops /etc/nomad.d/nomad.hcl + the
# systemd unit and brings the agent up. TLS certs
# (/etc/nomad.d/tls/{nomad.crt, nomad.key, ca-chain.crt}) and the
# Vault PKI CA (/opt/nomad/tls/vault-intermediate-ca.pem) are owned
# out-of-band by vault-cert-manager.
# -------------------------------------------------------------------------------

name             'nomad'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures HashiCorp Nomad (server and/or client mode)'
version          '0.3.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
