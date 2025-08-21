# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  helpers_spec.rb — RSpec Tests for Nomad::Helpers Library
#  Verifies helper methods for Nomad-related operations.
# ------------------------------------------------------------------------------

require 'spec_helper'
require_relative '../../libraries/helpers'

describe Nomad::Helpers do
  # --------------------------------------------------------------------------
  #  Dummy class to include the Helpers module for testing
  # --------------------------------------------------------------------------
  let(:dummy_class) { Class.new { include Nomad::Helpers } }
  let(:helper) { dummy_class.new }

  # --------------------------------------------------------------------------
  #  Test: nomad_version
  # --------------------------------------------------------------------------
  describe '#nomad_version' do
    let(:shellout_double) { double('Mixlib::ShellOut') }

    before do
      allow(Mixlib::ShellOut).to receive(:new)
        .with('/usr/local/bin/nomad version')
        .and_return(shellout_double)
      allow(shellout_double).to receive(:run_command)
    end

    context 'when nomad version output is present' do
      before { allow(shellout_double).to receive(:stdout).and_return("Nomad v1.6.2 (abcd1234)\n") }

      it 'returns the version string' do
        expect(helper.nomad_version).to eq('v1.6.2')
      end
    end

    context 'when nomad version output is empty' do
      before { allow(shellout_double).to receive(:stdout).and_return('') }

      it 'returns nil' do
        expect(helper.nomad_version).to be_nil
      end
    end
  end
end
