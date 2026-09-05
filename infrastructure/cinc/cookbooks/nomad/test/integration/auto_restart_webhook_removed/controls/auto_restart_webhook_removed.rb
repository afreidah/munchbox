# frozen_string_literal: true

# -------------------------------------------------------------------------------
# nomad::auto_restart_webhook :remove integration controls.
# -------------------------------------------------------------------------------

control 'webhook-removed-script' do
  impact 1.0
  title 'webhook python script is absent'

  describe file('/usr/local/bin/nomad-auto-restart-webhook.py') do
    it { should_not exist }
  end
end

control 'webhook-removed-systemd-unit' do
  impact 1.0
  title 'systemd unit file is absent and the service is not enabled'

  describe file('/etc/systemd/system/nomad-auto-restart-webhook.service') do
    it { should_not exist }
  end

  describe service('nomad-auto-restart-webhook') do
    it { should_not be_enabled }
    it { should_not be_running }
  end
end

control 'webhook-removed-consul-service-json' do
  impact 1.0
  title 'consul service-registration JSON is absent'

  describe file('/etc/consul.d/nomad-auto-restart-webhook.json') do
    it { should_not exist }
  end
end

control 'webhook-removed-runtime-paths' do
  impact 1.0
  title 'cooldown dir and log file are absent'

  describe directory('/tmp/nomad-restart-cooldown') do
    it { should_not exist }
  end

  describe file('/var/log/nomad-auto-restart.log') do
    it { should_not exist }
  end
end
