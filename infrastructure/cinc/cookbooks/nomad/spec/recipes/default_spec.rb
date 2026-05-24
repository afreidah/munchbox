# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec
#
# Empty by design -- nodes opt in via explicit install + configure
# entries in their run_list. Lock the empty-collection convention so a
# drive-by edit can't silently reintroduce default behavior.
# -------------------------------------------------------------------------------

RSpec.describe 'nomad::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('nomad::default') }

  # --- Empty recipe collection ---
  it 'converges with no resources (nodes opt in to install + configure explicitly)' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
