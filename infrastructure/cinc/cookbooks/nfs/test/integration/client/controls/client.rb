# frozen_string_literal: true

# -------------------------------------------------------------------------------
# nfs::client integration controls (package install only; no live mounts).
# -------------------------------------------------------------------------------

control 'nfs-common-installed' do
  impact 1.0
  title 'nfs-common package is installed'

  describe package('nfs-common') do
    it { should be_installed }
  end
end
