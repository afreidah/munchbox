# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cinc_client
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs and configures cinc-client on a node so it can register with
# (and pull cookbooks from) the munchbox cinc-server. Includes an
# opt-in systemd timer for periodic converges.
# -------------------------------------------------------------------------------

name             'cinc_client'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs and configures cinc-client'
version          '0.5.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
