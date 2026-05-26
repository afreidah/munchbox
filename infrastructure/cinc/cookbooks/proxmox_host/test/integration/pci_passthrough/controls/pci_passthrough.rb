# frozen_string_literal: true

# -------------------------------------------------------------------------------
# proxmox_host::pci_passthrough integration controls.
# -------------------------------------------------------------------------------

control 'pci_passthrough-grub-cmdline' do
  impact 1.0
  title '/etc/default/grub carries the PCI passthrough cmdline'

  describe file('/etc/default/grub') do
    it { should exist }
    its('content') { should match(/^GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"$/) }
  end
end

control 'pci_passthrough-modules' do
  impact 1.0
  title '/etc/modules lists the vfio kernel modules'

  %w(vfio vfio_iommu_type1 vfio_pci).each do |m|
    describe file('/etc/modules') do
      its('content') { should match(/^#{Regexp.escape(m)}$/) }
    end
  end
end

control 'pci_passthrough-vfio-modprobe' do
  impact 1.0
  title '/etc/modprobe.d/vfio.conf binds the configured device IDs at boot'

  describe file('/etc/modprobe.d/vfio.conf') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0644' }
    its('content') { should match(/^options vfio-pci ids=10de:2204,10de:1aef$/) }
  end
end
