# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# pinned_version library spec
#
# The helper is a data_bag_item lookup plus error classification, so the bag
# read is the only thing stubbed. Each example includes the module into a bare
# object carrying its own data_bag_item, which is closer to how recipes and
# resources acquire it than stubbing a Chef run would be.
# -------------------------------------------------------------------------------

RSpec.describe MunchboxLibPinnedVersion do
  # --- Minimal host for the module: supplies the data_bag_item the helper calls ---
  def caller_with(&block)
    Class.new do
      include MunchboxLibPinnedVersion
      define_method(:data_bag_item, &block)
    end.new
  end

  describe '#pinned_version' do
    it 'returns the version field from the versions data bag' do
      subject = caller_with { |bag, item| { 'id' => item, 'version' => "#{bag}-2.0.6" } }
      expect(subject.pinned_version('nomad')).to eq('versions-2.0.6')
    end

    it 'looks the tool up as an item in the versions bag' do
      seen = nil
      subject = caller_with do |bag, item|
        seen = [bag, item]
        { 'version' => '2.0.6' }
      end
      subject.pinned_version('consul')
      expect(seen).to eq(%w(versions consul))
    end

    # --- A present-but-empty pin is a misconfiguration, not a version ---
    it 'raises when the item carries no version field' do
      subject = caller_with { |_bag, _item| { 'id' => 'nomad' } }
      expect { subject.pinned_version('nomad') }
        .to raise_error(%r{versions/nomad has no 'version' field})
    end

    it 'raises when the version field is empty' do
      subject = caller_with { |_bag, _item| { 'version' => '' } }
      expect { subject.pinned_version('nomad') }
        .to raise_error(/has no 'version' field/)
    end

    # --- A missing item surfaces as guidance rather than a bare 404 ---
    it 'raises a message naming the item to create when the bag lookup 404s' do
      subject = caller_with do |_bag, _item|
        raise Net::HTTPClientException.new('404 "Not Found"', nil)
      end
      expect { subject.pinned_version('vault') }
        .to raise_error(%r{no version pinned for vault; create data bag item versions/vault})
    end

    it 'raises the same guidance when running without a server' do
      subject = caller_with do |_bag, _item|
        raise Chef::Exceptions::InvalidDataBagPath, 'no data bag path'
      end
      expect { subject.pinned_version('nomad') }
        .to raise_error(%r{create data bag item versions/nomad})
    end
  end
end
