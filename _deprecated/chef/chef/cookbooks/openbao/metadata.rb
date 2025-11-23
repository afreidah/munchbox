# frozen_string_literal: true

# ---------------------------------------------------------------------------------
# metadata.rb
#
#  This file contains metadata for the openbao Chef cookbook.
#
#  Defines cookbook name, maintainer, license, description, version, supported
#  platforms, and dependencies.
# ---------------------------------------------------------------------------------

name             'openbao'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'All rights reserved'
description      'Installs/Configures an OpenBao server' if File.exist?(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.0'

# --- Supported Platforms ---
supports 'ubuntu', '= 24.04'
