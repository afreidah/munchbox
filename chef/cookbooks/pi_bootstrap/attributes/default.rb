# pi_bootstrap::default attributes

# Prefix for the hostname; we'll append the Pi’s last octet
default['pi_bootstrap']['hostname_prefix'] = 'pi'

# WireGuard package name (adjust if you use a PPA)
# default['pi_bootstrap']['packages'] = %w[docker.io wireguard chrony]
default['pi_bootstrap']['packages'] = %w(docker.io)
