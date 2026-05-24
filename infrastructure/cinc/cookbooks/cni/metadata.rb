# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: cni
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs the containernetworking/plugins CNI binaries under /opt/cni/bin.
# Required for Nomad bridge networking and Consul Connect on every nomad
# server + client. Replaces ansible's install-cni-plugins.yml.
# -------------------------------------------------------------------------------

name             'cni'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs containernetworking/plugins under /opt/cni/bin'
version          '0.1.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'

supports 'debian'
supports 'ubuntu'
