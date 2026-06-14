# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: vault_agent
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs HashiCorp Vault Agent on a node, configures AppRole auto-auth
# against `auth/chef-approle/role/chef-managed-node`, and maintains a
# current Vault token in a sink file (`/run/vault-agent/token` by
# default). Chef cookbooks then call `secret('hashi_vault', ..., token:
# ::File.read('/run/vault-agent/token').strip)` -- no per-cookbook
# Vault auth logic.
# -------------------------------------------------------------------------------

name             'vault_agent'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures HashiCorp Vault Agent with AppRole auto-auth'
version          '0.5.2'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
