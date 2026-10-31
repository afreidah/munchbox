# frozen_string_literal: true

require 'spec_helper'

# -------------------------------------------------------------------------------
# publish recipe spec
#
# Steps into cinc_server_vault_publish with vault_kv_read / vault_kv_write
# stubbed on the munchbox_lib module, and the webui pem reads stubbed, so the
# write-only-on-change logic runs without Vault or the server's keys.
# -------------------------------------------------------------------------------

RSpec.describe 'cinc_server::publish' do
  let(:vault_path) { 'secret/data/cinc-server/webui' }
  let(:keypair)    { { 'private_key' => 'PRIV', 'public_key' => 'PUB' } }
  let(:writes)     { [] }

  # --- stored: what vault_kv_read returns for the path ---
  def converge_with(stored)
    recorded = writes
    MunchboxLibVaultFetch.module_eval do
      define_method(:vault_kv_read) { |_path| stored }
      define_method(:vault_kv_write) { |path, data| recorded << [path, data] }
    end
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with('/etc/cinc-project/webui_priv.pem').and_return('PRIV')
    allow(File).to receive(:read).with('/etc/cinc-project/webui_pub.pem').and_return('PUB')
    ChefSpec::SoloRunner.new(step_into: %w(cinc_server_vault_publish)).converge('cinc_server::publish')
  end

  it 'declares the publish resource for the webui keypair' do
    chef_run = converge_with(nil)
    expect(chef_run).to publish_cinc_server_vault_publish(vault_path)
      .with(files: {
              'private_key' => '/etc/cinc-project/webui_priv.pem',
              'public_key' => '/etc/cinc-project/webui_pub.pem',
            })
  end

  it 'writes both halves when nothing is stored yet' do
    converge_with(nil)
    expect(writes).to eq([[vault_path, keypair]])
  end

  it 'writes when the stored copy differs' do
    converge_with('private_key' => 'OLD', 'public_key' => 'PUB')
    expect(writes).to eq([[vault_path, keypair]])
  end

  it 'leaves Vault alone when the stored copy matches' do
    chef_run = converge_with(keypair)
    expect(writes).to be_empty
    expect(chef_run.cinc_server_vault_publish(vault_path)).not_to be_updated_by_last_action
  end
end
