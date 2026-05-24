# frozen_string_literal: true

name 'vault'
maintainer       'Alex Freidah'
license          'All Rights Reserved'
description      'Installs + configures HashiCorp Vault server (consul storage backend, HA)'
version          '0.1.0'
chef_version     '>= 19.0'

depends 'munchbox_lib'
