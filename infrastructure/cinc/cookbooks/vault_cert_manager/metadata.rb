# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_cert_manager
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs the vault-cert-manager daemon (built from src/vault-cert-manager,
# shipped via the munchbox aptly repo) and configures it to keep the
# consul + nomad TLS certs on each node renewed from Vault PKI. AppRole
# creds come from Vault (shared role_id + secret_id; per-node secret_ids
# are a future improvement).
# -------------------------------------------------------------------------------

name             'vault_cert_manager'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures vault-cert-manager (Vault PKI cert lifecycle daemon)'
version          '0.1.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
