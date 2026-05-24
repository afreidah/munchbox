# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec
#
# Empty by design -- nodes opt in via explicit recipe entries in their
# role (e.g. recipe[oracle::watchdog] from role[oracle_node]).
# -------------------------------------------------------------------------------

RSpec.describe 'oracle::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('oracle::default') }

  # --- Empty recipe collection ---
  it 'converges with no resources' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
