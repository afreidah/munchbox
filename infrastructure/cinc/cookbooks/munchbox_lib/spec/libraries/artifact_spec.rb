# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'digest'

RSpec.describe MunchboxLibCookbook::Artifact do
  # -------------------------------------------------------------------------------
  # normalize_arch
  # -------------------------------------------------------------------------------

  describe '.normalize_arch' do
    # --- aarch64/arm64 both normalize to arm64 ---
    it 'maps aarch64 and arm64 to arm64' do
      expect(described_class.normalize_arch('aarch64')).to eq('arm64')
      expect(described_class.normalize_arch('arm64')).to eq('arm64')
    end

    # --- x86_64/amd64 both normalize to amd64 ---
    it 'maps x86_64 and amd64 to amd64' do
      expect(described_class.normalize_arch('x86_64')).to eq('amd64')
      expect(described_class.normalize_arch('amd64')).to eq('amd64')
    end

    # --- unknown arch is a hard error, not a silent default ---
    it 'raises on an unsupported architecture' do
      expect { described_class.normalize_arch('riscv64') }.to raise_error(/unsupported machine/)
    end
  end

  # -------------------------------------------------------------------------------
  # hashicorp_url / hashicorp_sums_url
  # -------------------------------------------------------------------------------

  describe '.hashicorp_url' do
    # --- consul/nomad/vault all share the releases.hashicorp.com archive shape ---
    it 'builds the per-product/version/arch release archive url' do
      expect(described_class.hashicorp_url('consul', '2.0.0', 'arm64'))
        .to eq('https://releases.hashicorp.com/consul/2.0.0/consul_2.0.0_linux_arm64.zip')
      expect(described_class.hashicorp_url('nomad', '2.0.3', 'amd64'))
        .to eq('https://releases.hashicorp.com/nomad/2.0.3/nomad_2.0.3_linux_amd64.zip')
    end
  end

  describe '.hashicorp_sums_url' do
    # --- the SHA256SUMS sibling of the archive; basename of the archive keys the lookup ---
    it 'builds the SHA256SUMS url for the release' do
      expect(described_class.hashicorp_sums_url('vault', '2.0.1'))
        .to eq('https://releases.hashicorp.com/vault/2.0.1/vault_2.0.1_SHA256SUMS')
    end
  end

  # -------------------------------------------------------------------------------
  # sha256_for (SHA256SUMS parsing)
  # -------------------------------------------------------------------------------

  describe '.sha256_for' do
    let(:sums) do
      <<~SUMS
        aaaa1111  consul_1.22.7_linux_amd64.zip
        bbbb2222  consul_1.22.7_linux_arm64.zip
      SUMS
    end

    # --- returns the sha matching the requested filename ---
    it 'returns the sha for the requested file' do
      expect(described_class.sha256_for(sums, 'consul_1.22.7_linux_arm64.zip')).to eq('bbbb2222')
    end

    # --- a filename not in the body is a hard error ---
    it 'raises when the filename is absent' do
      expect { described_class.sha256_for(sums, 'nope.zip') }.to raise_error(/not present in SHA256SUMS/)
    end
  end

  # -------------------------------------------------------------------------------
  # verify! (the integrity gate)
  # -------------------------------------------------------------------------------

  describe '.verify!' do
    around do |example|
      Dir.mktmpdir('artifact_spec') do |dir|
        @path = File.join(dir, 'artifact.bin')
        File.write(@path, 'munchbox-artifact-payload')
        example.run
      end
    end

    let(:good) { Digest::SHA256.hexdigest('munchbox-artifact-payload') }

    # --- a matching checksum passes (case-insensitive) ---
    it 'returns true when the checksum matches' do
      expect(described_class.verify!(@path, good)).to be(true)
      expect(described_class.verify!(@path, good.upcase)).to be(true)
    end

    # --- a wrong checksum raises (download tampered/corrupt) ---
    it 'raises on a checksum mismatch' do
      expect { described_class.verify!(@path, 'deadbeef') }.to raise_error(/checksum mismatch/)
    end

    # --- a nil/empty expected checksum is fail-closed, never a pass ---
    it 'raises when no expected checksum is supplied' do
      expect { described_class.verify!(@path, nil) }.to raise_error(/no expected checksum/)
      expect { described_class.verify!(@path, '') }.to raise_error(/no expected checksum/)
    end
  end
end
