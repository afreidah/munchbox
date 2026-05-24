# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vault_agent::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('vault_agent::default') }

  it 'converges with no resources' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
