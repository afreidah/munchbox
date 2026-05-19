# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_server
#
# Project: Munchbox / Author: Alex Freidah
#
# Stands up a single-node cinc-server. Downloads the cinc-server .deb,
# installs it, templates /etc/opscode/chef-server.rb, and runs
# `chef-server-ctl reconfigure` when the config changes.
# -------------------------------------------------------------------------------

name             'cinc_server'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs and configures the cinc-server'
version          '0.1.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'

supports 'debian'
supports 'ubuntu'
