# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  consul_helpers_spec.rb — RSpec tests for ConsulCookbook helper methods
# ------------------------------------------------------------------------------

require 'spec_helper'
require_relative '../../libraries/consul_helpers'

describe ConsulCookbook do
  describe '.archive_arch' do
    it 'returns linux_amd64 for x86_64' do
      expect(described_class.archive_arch('x86_64')).to eq('linux_amd64')
    end

    it 'returns linux_arm64 for aarch64' do
      expect(described_class.archive_arch('aarch64')).to eq('linux_arm64')
    end

    it 'returns linux_arm64 for arm64' do
      expect(described_class.archive_arch('arm64')).to eq('linux_arm64')
    end

    it 'returns linux_amd64 for unknown arch' do
      expect(described_class.archive_arch('foobar')).to eq('linux_amd64')
    end
  end

  describe '.archive_url' do
    it 'builds the correct Consul archive URL' do
      expect(described_class.archive_url('1.15.2', 'linux_amd64')).to eq(
        'https://releases.hashicorp.com/consul/1.15.2/consul_1.15.2_linux_amd64.zip'
      )
    end
  end
end
