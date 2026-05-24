# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs Docker CE from the upstream Docker apt repo and (optionally)
# templates /etc/docker/daemon.json. Adds the nomad system user to the
# docker group so nomad's docker driver can launch containers without
# root. Arch-aware (arm64 / amd64).
# -------------------------------------------------------------------------------

name             'docker'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs + configures Docker CE for nomad container workloads'
version          '0.3.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
