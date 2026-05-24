# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: oracle
#
# Project: Munchbox / Author: Alex Freidah
#
# Oracle Cloud-specific concerns that don't fit a generic cookbook:
#   - oracle::watchdog     -- installs the oracle-watchdog package (from
#     the munchbox aptly repo) + consul integration (service registration,
#     ACL token from Vault).
#   - oracle::minio_mount  -- persists the OCI block volume (label
#     minio-data) at /mnt/minio-data via UUID-based fstab.
# -------------------------------------------------------------------------------

name             'oracle'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Oracle Cloud-specific concerns (watchdog, minio mount, etc)'
version          '0.2.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
supports 'ubuntu'
