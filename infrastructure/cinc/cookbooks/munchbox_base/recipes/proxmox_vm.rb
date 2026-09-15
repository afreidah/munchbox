# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: proxmox_vm
#
# Packages a Proxmox-hosted guest needs. qemu-guest-agent gives the hypervisor
# graceful shutdown, guest IP reporting, and filesystem freeze during backups.
# Its unit is BindsTo the virtio-ports device, so it stays inactive anywhere
# the channel is absent.
# -------------------------------------------------------------------------------

munchbox_base_packages 'proxmox-vm' do
  packages %w(qemu-guest-agent)
end

# --- The unit is static, so it cannot be enabled; the packaged udev rule starts
#     it on device-add. On a host whose virtio port was plugged before the
#     package existed, that event has already passed and only a start recovers it. ---
service 'qemu-guest-agent' do
  action :start
end
