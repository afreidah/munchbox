# frozen_string_literal: true

name             'proxmox_host'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'All Rights Reserved'
description      'Proxmox VE hypervisor concerns: ZFS arc cap, GPU enablement (GVT-g + PCI passthrough), zfswatcher, sysctl/KSM/apt-repo tuning, kernel cmdline.'
version          '0.4.0'
chef_version     '>= 19.0'

supports 'debian'

depends 'munchbox_lib'
depends 'munchbox_base'
