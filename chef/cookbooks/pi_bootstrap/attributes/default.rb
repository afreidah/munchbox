# frozen_string_literal: true

# --------------------------------------------------------------------
# Cookbook:: pi_bootstrap
# Attributes:: default
#
# Default attributes for Raspberry Pi bootstrap configuration.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Hostname Configuration
# --------------------------------------------------------------------
default['pi_bootstrap']['hostname_prefix'] = 'pi'   # Prefix; last octet appended at converge

# --------------------------------------------------------------------
# Package Installation
# --------------------------------------------------------------------
# Raspberry Pi OS (raspbian/bookworm) specifics:
# - telnet is provided by inetutils-telnet (avoid the virtual 'telnet')
# - dnsutils is replaced by bind9-dnsutils on Debian 12+/Raspbian
# - containernetworking-plugins is the correct CNI package name on Raspbian
default['pi_bootstrap']['packages'] = %w(
  curl
  docker.io
  dmidecode
  inetutils-telnet
  bind9-dnsutils
  net-tools
  containernetworking-plugins
)

# --- Node that acts as Docker Registry ---
default['pi_bootstrap']['docker_registry_node'] = 'goren'

