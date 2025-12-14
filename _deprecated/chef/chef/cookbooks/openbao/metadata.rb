# frozen_string_literal: true

# -------------------------------------------------------------------------------
# OpenBao Cookbook - Metadata
#
# Project: Munchbox / Author: Alex Freidah
#
# Cookbook metadata for OpenBao installation and configuration.
# -------------------------------------------------------------------------------

name             'openbao'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'All rights reserved'
description      'Installs/Configures an OpenBao server' if File.exist?(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.0'

# --- Supported Platforms ---
supports 'ubuntu', '= 24.04'
