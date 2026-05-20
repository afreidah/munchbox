# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# disable_apt_daily recipe spec
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_client::disable_apt_daily' do
  cached(:chef_run) { ChefSpec::SoloRunner.new.converge('cinc_client::disable_apt_daily') }

  %w(apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service).each do |unit|
    it "stops, disables, and masks #{unit}" do
      expect(chef_run).to stop_systemd_unit(unit)
      expect(chef_run).to disable_systemd_unit(unit)
      expect(chef_run).to mask_systemd_unit(unit)
    end
  end
end
