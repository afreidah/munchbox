# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: pi_bootstrap
# Metadata
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Cookbook:: metadata for Raspberry Pi bootstrap configuration.
# --------------------------------------------------------------------

name             'pi_bootstrap'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'Apache-2.0'
description      'Basic OS setup for Raspberry Pi nodes'
version          '0.1.0'

chef_version     '>= 16.0'
supports         'raspbian'
supports         'ubuntu'

depends 'firewall'
