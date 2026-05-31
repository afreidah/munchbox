# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: disable_timesyncd
#
# Forces node['munchbox_base']['timesync']['enabled'] = false so the
# munchbox_base::timesync recipe early-returns. Apply on hosts that run a
# different time daemon (e.g. chrony) or that don't ship a systemd-timesyncd
# unit at all.
# -------------------------------------------------------------------------------

name 'disable_timesyncd'
description 'Skip the chef-managed systemd-timesyncd recipe (override-precedence)'

override_attributes(
  munchbox_base: {
    timesync: {
      enabled: false,
    },
  },
)
