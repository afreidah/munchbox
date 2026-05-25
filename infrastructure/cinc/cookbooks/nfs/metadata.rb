# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nfs
#
# Project: Munchbox / Author: Alex Freidah
#
# Reusable NFS client cookbook: installs nfs-common and exposes a
# `nfs_mount` resource any cookbook/role can use to declare a mount.
# Today's first consumer is the gdrive export from mccoy, but the
# resource is generic so future mounts (CIFS-replaced shares, oracle
# block exports, etc.) drop straight in.
# -------------------------------------------------------------------------------

name             'nfs'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'NFS client install + reusable nfs_mount resource'
version          '0.1.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'

supports 'debian'
supports 'ubuntu'
