# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nvidia
#
# Project: Munchbox / Author: Alex Freidah
#
# Installs the Debian-shipped NVIDIA proprietary driver and the NVIDIA
# Container Toolkit so the docker `nvidia` runtime (declared elsewhere
# via docker.daemon.extra) actually has the runtime binary present. Opt
# nodes in by adding `recipe[nvidia::install]` to a per-node role;
# there's no fleet role since only the GPU host runs this today.
# -------------------------------------------------------------------------------

name             'nvidia'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Installs NVIDIA driver + nvidia-container-toolkit on GPU hosts'
version          '0.1.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'

depends 'munchbox_lib'
depends 'munchbox_base'

supports 'debian'
