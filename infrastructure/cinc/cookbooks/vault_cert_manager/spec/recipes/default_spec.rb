# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# default recipe spec
#
# Empty by design -- nodes opt in via explicit role[vault_cert_manager]
# entries in their run_list.
# -------------------------------------------------------------------------------

RSpec.describe 'vault_cert_manager::default' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('vault_cert_manager::default') }

  # --- Empty recipe collection ---
  it 'converges with no resources' do
    expect(chef_run.resource_collection.to_a).to be_empty
  end
end
