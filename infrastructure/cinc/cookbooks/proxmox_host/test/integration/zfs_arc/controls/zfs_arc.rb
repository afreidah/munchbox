# frozen_string_literal: true

# -------------------------------------------------------------------------------
# proxmox_host::zfs_arc integration controls.
# The live sysfs write is gated on /sys/module/zfs/parameters/zfs_arc_max being
# present, which it isn't on a non-ZFS guest -- we only assert the on-disk
# drop-in here.
# -------------------------------------------------------------------------------

control 'zfs-arc-drop-in' do
  impact 1.0
  title '/etc/modprobe.d/zfs.conf carries the requested ARC cap'

  describe file('/etc/modprobe.d/zfs.conf') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0644' }
    its('content') { should match(/^options zfs zfs_arc_max=34359738368$/) }
  end
end
