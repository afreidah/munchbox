# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# vault_fetch helper spec
#
# Exercises the module's logic against a stub host that responds to `secret`.
# We don't load chef-vault here -- we just verify that the helper:
#   - guards on the token sink existing
#   - reads + strips the sink contents
#   - calls `secret` with the right kwargs
#   - unwraps KV v2 responses
#   - tolerates string OR symbol field keys
#   - raises with an actionable message if the field is missing
# -------------------------------------------------------------------------------

RSpec.describe MunchboxLibVaultFetch do
  # --- Bare host class that mixes in the module + a fake `secret` impl per example ---
  let(:host_class) do
    Class.new do
      include MunchboxLibVaultFetch
      attr_accessor :secret_response, :captured_call

      def secret(**kwargs)
        @captured_call = kwargs
        @secret_response
      end
    end
  end
  let(:host) { host_class.new }

  before do
    allow(::File).to receive(:exist?).and_call_original
    allow(::File).to receive(:exist?).with(described_class::VAULT_TOKEN_SINK).and_return(true)
    allow(::File).to receive(:read).with(described_class::VAULT_TOKEN_SINK).and_return("hvs.testtoken\n")
    # --- Avoid the workstation's munchbox-env.sh VAULT_ADDR leaking into the default-path assertion ---
    stub_const('ENV', ENV.to_h.merge('VAULT_ADDR' => nil).compact)
  end

  it 'raises a clear message when the token sink never appears within the wait window' do
    allow(::File).to receive(:exist?).with(described_class::VAULT_TOKEN_SINK).and_return(false)
    # --- Stub sleep to keep the test instant; the retry loop should still exit on the deadline. ---
    stub_const("#{described_class}::VAULT_TOKEN_WAIT_SECONDS", 0.01)
    stub_const("#{described_class}::VAULT_TOKEN_WAIT_INTERVAL", 0.001)
    expect { host.vault_fetch('secret/data/foo', 'k') }
      .to raise_error(/vault token sink .* not present after [\d.]+s; is vault-agent running/)
  end

  it 'retries until the token sink appears within the wait window' do
    call_count = 0
    allow(::File).to receive(:exist?).with(described_class::VAULT_TOKEN_SINK) do
      call_count += 1
      call_count >= 3 # appears on the third poll
    end
    stub_const("#{described_class}::VAULT_TOKEN_WAIT_SECONDS", 0.01)
    stub_const("#{described_class}::VAULT_TOKEN_WAIT_INTERVAL", 0.001)
    host.secret_response = { data: { 'k' => 'v' } }
    expect(host.vault_fetch('secret/data/foo', 'k')).to eq('v')
    expect(call_count).to be >= 3
  end

  it 'passes the stripped token + default vault_addr to secret()' do
    host.secret_response = { data: { 'k' => 'v' } }
    host.vault_fetch('secret/data/foo', 'k')
    expect(host.captured_call[:config][:token]).to eq('hvs.testtoken')
    expect(host.captured_call[:config][:vault_addr]).to eq(described_class::VAULT_ADDR_DEFAULT)
  end

  it 'unwraps a KV v2 response and returns the field value (string key)' do
    host.secret_response = { data: { 'private_key' => 'PRIV' }, metadata: { 'version' => 1 } }
    expect(host.vault_fetch('secret/data/wireguard-v2/x', 'private_key')).to eq('PRIV')
  end

  it 'tolerates symbol-keyed inner data hashes' do
    host.secret_response = { data: { private_key: 'PRIV_SYM' } }
    expect(host.vault_fetch('secret/data/wireguard-v2/x', 'private_key')).to eq('PRIV_SYM')
  end

  it 'returns the field from an already-flat response (non-wrapped)' do
    host.secret_response = { 'role_id' => 'RID' }
    expect(host.vault_fetch('secret/data/foo', 'role_id')).to eq('RID')
  end

  it 'raises with an actionable message when the field is missing' do
    host.secret_response = { data: { 'other_key' => 'x' } }
    expect { host.vault_fetch('secret/data/wireguard-v2/x', 'private_key') }
      .to raise_error(%r{vault: no field 'private_key' at secret/data/wireguard-v2/x})
  end
end
