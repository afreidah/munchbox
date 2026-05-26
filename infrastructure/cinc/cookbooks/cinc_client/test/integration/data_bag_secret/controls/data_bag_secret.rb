# frozen_string_literal: true

# -------------------------------------------------------------------------------
# cinc_client::data_bag_secret integration controls.
#
# pre_converge stages a placeholder /etc/cinc/encrypted_data_bag_secret as
# mode 0644 root:root. The recipe's ruby_block then verifies presence (passes
# because the file is there) and the file resource lowers perms to 0640.
# -------------------------------------------------------------------------------

control 'cinc-config-dir' do
  impact 1.0
  title '/etc/cinc exists root:root 0755'

  describe directory('/etc/cinc') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
  end
end

control 'encrypted-data-bag-secret-perms' do
  impact 1.0
  title 'encrypted_data_bag_secret is locked down to 0640 root:root (recipe tightens the placeholder mode)'

  describe file('/etc/cinc/encrypted_data_bag_secret') do
    it { should exist }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0640' }
  end
end
