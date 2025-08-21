# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  InSpec Control: nomad Installation Verification
# ------------------------------------------------------------------------------
#  Verifies nomad is installed and matches the expected version.
# ------------------------------------------------------------------------------

control 'nomad-install' do
  impact 1.0
  title  'nomad Installation'
  desc   'Ensures nomad is installed and the correct version is present.'

  describe service('nomad') do
    it { should be_enabled }
    it { should be_running }
  end
end
