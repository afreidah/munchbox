# frozen_string_literal: true

# -------------------------------------------------------------------------------
# proxmox_host::gvt_g integration controls.
#
# Asserts on-disk artifacts only (chef's job). Verifying the iGPU is
# actually mediated requires real Intel silicon + a reboot; do that on
# the actual hypervisor with `ls /sys/bus/pci/drivers/i915` post-reboot.
# -------------------------------------------------------------------------------

control 'gvt_g-grub-cmdline' do
  impact 1.0
  title '/etc/default/grub carries the GVT-g cmdline'

  describe file('/etc/default/grub') do
    it { should exist }
    its('content') { should match(/^GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on i915\.enable_gvt=1"$/) }
  end
end

control 'gvt_g-modules' do
  impact 1.0
  title '/etc/modules lists the vfio + kvmgt kernel modules'

  %w(kvmgt vfio-iommu-type1 vfio-mdev).each do |m|
    describe file('/etc/modules') do
      its('content') { should match(/^#{Regexp.escape(m)}$/) }
    end
  end
end
