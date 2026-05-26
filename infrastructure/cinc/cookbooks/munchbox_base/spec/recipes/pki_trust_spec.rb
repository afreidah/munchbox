# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# pki_trust recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::pki_trust' do
  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_pki_trust)).converge('munchbox_base::pki_trust')
  end

  it 'declares the wrapping resource keyed by munchbox-pki' do
    expect(chef_run).to install_munchbox_base_pki_trust('munchbox-pki')
  end

  %w(munchbox-root-ca.crt munchbox-intermediate-ca.crt).each do |basename|
    it "drops #{basename} under /usr/local/share/ca-certificates/ with 0644 root:root" do
      expect(chef_run).to create_cookbook_file("/usr/local/share/ca-certificates/#{basename}")
        .with(source: basename, cookbook: 'munchbox_base', owner: 'root', group: 'root', mode: '0644')
    end

    it "#{basename} notifies update-ca-certificates (delayed) on change" do
      expect(chef_run.cookbook_file("/usr/local/share/ca-certificates/#{basename}"))
        .to notify('execute[update-ca-certificates]').to(:run).delayed
    end
  end

  it 'declares update-ca-certificates as :nothing (notify-driven only)' do
    expect(chef_run.execute('update-ca-certificates')).to do_nothing
  end
end
