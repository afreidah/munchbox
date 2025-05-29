# frozen_string_literal: true
#
# Cookbook:: pi_bootstrap
# Attributes:: default
#
# Copyright:: 2024, Alex Freidah, All Rights Reserved.
#
# Default attributes for Raspberry Pi bootstrap configuration.
#

# =========================
# Hostname Configuration
# =========================

# Prefix for the hostname; the Pi’s last octet will be appended
default['pi_bootstrap']['hostname_prefix'] = 'pi'

# =========================
# Package Installation
# =========================

# List of packages to install (adjust as needed)
default['pi_bootstrap']['packages'] = %w(
  docker.io
  dmidecode
  telnet
  dnsutils
  net-tools
  containernetworking-plugins 
)
