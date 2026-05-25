# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
#
# Project: Munchbox / Author: Alex Freidah
#
# Wide base cookbook. Runs on every node and owns OS-level prerequisites:
# packages, apt repo, time sync, journald, sshd hardening. Other cookbooks
# assume munchbox_base has already converged.
# -------------------------------------------------------------------------------

name             'munchbox_base'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'OS-level prerequisites every Munchbox node needs'
version          '0.9.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'

supports 'debian'
supports 'ubuntu'
