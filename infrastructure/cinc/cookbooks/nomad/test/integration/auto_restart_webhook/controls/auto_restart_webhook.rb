# frozen_string_literal: true

# -------------------------------------------------------------------------------
# nomad::auto_restart_webhook integration controls.
# -------------------------------------------------------------------------------

control 'webhook-script' do
  impact 1.0
  title 'webhook python script is rendered + executable with the configured port'

  describe file('/usr/local/bin/nomad-auto-restart-webhook.py') do
    it { should exist }
    it { should be_executable }
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755' }
    its('content') { should match(/9095/) }
  end
end

control 'webhook-systemd-unit' do
  impact 1.0
  title 'systemd unit installed + enabled with NOMAD_TOKEN env from the attribute override'

  describe file('/etc/systemd/system/nomad-auto-restart-webhook.service') do
    it { should exist }
    its('content') { should match(%r{^ExecStart=/usr/bin/python3 /usr/local/bin/nomad-auto-restart-webhook\.py$}) }
    its('content') { should match(/^Environment=NOMAD_TOKEN=kitchen-fake-nomad-token$/) }
  end

  describe service('nomad-auto-restart-webhook') do
    it { should be_enabled }
    # Not asserting be_running -- daemon flaps because no nomad agent on :4646.
  end
end

control 'webhook-consul-service-json' do
  impact 1.0
  title 'consul service-registration JSON is rendered with the configured port'

  describe file('/etc/consul.d/nomad-auto-restart-webhook.json') do
    it { should exist }
    its('mode') { should cmp '0640' }
    its('content') { should match(/"name":\s*"nomad-auto-restart-webhook"/) }
    its('content') { should match(/"port":\s*9095/) }
  end
end

control 'webhook-stale-paths' do
  impact 1.0
  title 'ansible-era .sh leftover is swept'

  describe file('/usr/local/bin/nomad-auto-restart-webhook.sh') do
    it { should_not exist }
  end
end
