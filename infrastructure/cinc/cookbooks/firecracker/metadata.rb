# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: firecracker
#
# Project: Munchbox / Author: Alex Freidah
#
# Readies a node to run Vagabond workloads in Firecracker microVMs: the user
# Firecracker runs as, and containerd's devmapper snapshotter on a thin pool
# over sparse files. Opt nodes in with `recipe[firecracker::host]`; the node
# needs /dev/kvm and Docker's containerd.
# -------------------------------------------------------------------------------

name             'firecracker'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Readies a node for Vagabond Firecracker microVMs'
version          '0.1.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
