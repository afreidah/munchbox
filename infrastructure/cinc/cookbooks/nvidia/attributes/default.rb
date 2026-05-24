# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: nvidia
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Install
#
# - debian_nonfree_components: enables main + contrib + non-free +
#     non-free-firmware on the debian repo so apt can resolve `nvidia-driver`.
# - container_toolkit_*: NVIDIA's apt repo for nvidia-container-toolkit.
#     URL uses apt's literal `$(ARCH)` substitution.
# - install_kernel_headers: pull `linux-headers-<running-kernel>` so DKMS-style
#     driver upgrades after a kernel update don't break. Resolved at converge
#     time from node['kernel']['release'].
# - packages: nvidia-driver pulls in the libnvidia-* / glx / firmware stack
#     transitively. nvidia-container-toolkit pulls in libnvidia-container1
#     and the toolkit binaries.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  debian_nonfree_components: %w(main contrib non-free non-free-firmware),
  container_toolkit_repo_uri: 'https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)',
  container_toolkit_key_url: 'https://nvidia.github.io/libnvidia-container/gpgkey',
  install_kernel_headers: true,
  packages: %w(nvidia-driver nvidia-container-toolkit),
}
