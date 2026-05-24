# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# data_bag_secret recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::data_bag_secret' do
  context 'when /etc/cinc/encrypted_data_bag_secret is present' do
    cached(:chef_run) do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/etc/cinc/encrypted_data_bag_secret').and_return(true)
      ChefSpec::SoloRunner.new.converge('cinc_client::data_bag_secret')
    end

    it 'creates /etc/cinc with 0755 root:root' do
      expect(chef_run).to create_directory('/etc/cinc').with(owner: 'root', group: 'root', mode: '0755')
    end

    it 'enforces 0640 root:root on the secret file (without touching content)' do
      expect(chef_run).to create_file('/etc/cinc/encrypted_data_bag_secret')
        .with(owner: 'root', group: 'root', mode: '0640')
    end
  end

  context 'when the secret file is missing' do
    cached(:chef_run) do
      allow(::File).to receive(:exist?).and_call_original
      allow(::File).to receive(:exist?).with('/etc/cinc/encrypted_data_bag_secret').and_return(false)
      ChefSpec::SoloRunner.new.converge('cinc_client::data_bag_secret')
    end

    it 'declares the guard ruby_block so chef raises at runtime before any dependent resource runs' do
      expect(chef_run).to run_ruby_block('verify encrypted_data_bag_secret is present')
    end
  end
end
