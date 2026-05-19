# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: journald
#
# Applies journald disk/retention limits from node attributes via a
# /etc/systemd/journald.conf.d drop-in.
# -------------------------------------------------------------------------------

munchbox_base_journald 'baseline' do
  settings node[cookbook]['journald'].to_hash
end
