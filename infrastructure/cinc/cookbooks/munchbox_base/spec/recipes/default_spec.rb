# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# Default recipe spec
#
# The default recipe is intentionally empty -- consumers cherry-pick the
# sub-recipes they need. This spec just asserts a clean converge with no
# resources declared, so the empty-recipe contract is enforced.
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new.converge('munchbox_base::default') }

  it 'converges without declaring any resources' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
