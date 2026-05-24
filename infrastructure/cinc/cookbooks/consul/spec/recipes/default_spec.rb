# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec
#
# The default recipe is intentionally empty -- nodes opt in to install +
# configure via explicit run_list entries. This spec just locks that
# convention in place so a future drive-by edit doesn't silently
# reintroduce default behavior.
# -------------------------------------------------------------------------------

RSpec.describe 'consul::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('consul::default') }

  # --- Empty recipe collection ---
  it 'converges with no resources (nodes opt in to install + configure explicitly)' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
