# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec -- intentionally empty; opt in via role.
# -------------------------------------------------------------------------------

RSpec.describe 'vault::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

  it 'converges without declaring any resources' do
    expect(chef_run.resource_collection.map(&:to_s)).to be_empty
  end
end
