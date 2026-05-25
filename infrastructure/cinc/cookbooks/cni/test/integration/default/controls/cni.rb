# frozen_string_literal: true

# -------------------------------------------------------------------------------
# cni::install integration controls.
# -------------------------------------------------------------------------------

control 'cni-install-dir' do
  impact 1.0
  title '/opt/cni/bin exists root:root 0755'

  describe directory('/opt/cni/bin') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
  end
end

control 'cni-plugins-present' do
  impact 1.0
  title 'expected CNI plugin binaries are installed + executable'

  %w(loopback bridge host-local portmap).each do |plugin|
    describe file("/opt/cni/bin/#{plugin}") do
      it { should exist }
      it { should be_executable }
    end
  end
end

control 'cni-version-stamp' do
  impact 1.0
  title '/opt/cni/bin/.cni-version records the installed version'

  describe file('/opt/cni/bin/.cni-version') do
    it { should exist }
    its('content') { should match(/^v1\.4\.0/) }
  end
end
