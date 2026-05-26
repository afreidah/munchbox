# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# apt_cleanup recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'munchbox_base::apt_cleanup' do
  # --- only_if shell guards on the autoremove + clean executes; stub positive so the actions fire ---
  before do
    stub_command('apt-get -s autoremove 2>/dev/null | grep -qE "^Remv "').and_return(true)
    stub_command('find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -print -quit | grep -q .').and_return(true)
  end

  cached(:chef_run) do
    ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_apt_cleanup))
                        .converge('munchbox_base::apt_cleanup')
  end

  # --- Wrapping resource gets credit for coverage ---
  it 'declares the apt_cleanup wrapping resource' do
    expect(chef_run).to run_munchbox_base_apt_cleanup('baseline')
  end

  # --- Waits for the dpkg lock before any apt operation ---
  it 'waits for the apt lock' do
    expect(chef_run).to wait_munchbox_base_apt_lock_wait('apt_cleanup-baseline')
  end

  # --- Runs autoremove --purge and apt clean ---
  it 'runs apt-get autoremove --purge -y' do
    expect(chef_run).to run_execute('apt-get autoremove --purge -y')
  end

  it 'runs apt-get clean' do
    expect(chef_run).to run_execute('apt-get clean')
  end

  # --- Defaults can be turned off via attribute ---
  context 'with autoremove disabled via attribute' do
    cached(:chef_run) do
      stub_command('find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -print -quit | grep -q .').and_return(true)
      ChefSpec::SoloRunner.new(step_into: %w(munchbox_base_apt_cleanup)) do |node|
        node.override[:munchbox_base][:apt_cleanup][:autoremove] = false
      end.converge('munchbox_base::apt_cleanup')
    end

    it 'skips the autoremove execute' do
      expect(chef_run).to_not run_execute('apt-get autoremove --purge -y')
    end

    it 'still runs apt-get clean' do
      expect(chef_run).to run_execute('apt-get clean')
    end
  end
end
