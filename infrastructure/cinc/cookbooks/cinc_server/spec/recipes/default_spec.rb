# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec -- recipe is intentionally empty so the only assertion
# is that it loads and converges without declaring any resources.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('cinc_server::default') }

  it 'converges with no resources' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
