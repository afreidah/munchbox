# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Library:: pinned_version
#
# `pinned_version(tool)` -- the version of a HashiCorp binary the cluster is
# pinned to, read from the `versions` data bag. One item per tool, keyed by
# cookbook name: versions/nomad, versions/consul, versions/vault.
#
# The bag is the only place a version is declared. munchbox-hashi-upgrade
# writes it as part of a rolling upgrade; this repository declares no version
# at all, so there is no second copy to drift from and bumping one is an API
# call rather than a pull request.
#
# Missing pins raise. A pin only goes absent through misconfiguration -- the
# bag comes from the same Chef server as the cookbooks, so a node that cannot
# read it never got far enough to converge -- and falling back to a literal
# would install a stale version instead of naming the problem.
# -------------------------------------------------------------------------------

module MunchboxLibPinnedVersion
  # --- One item per tool, keyed by cookbook name ---
  VERSIONS_DATA_BAG = 'versions'

  # --- Return the pinned version string for `tool`; raises when unset ---
  def pinned_version(tool)
    item = data_bag_item(VERSIONS_DATA_BAG, tool)
    version = item['version'].to_s
    raise "munchbox_lib: #{VERSIONS_DATA_BAG}/#{tool} has no 'version' field" if version.empty?

    version
  rescue Net::HTTPClientException, Chef::Exceptions::InvalidDataBagPath => e
    raise "munchbox_lib: no version pinned for #{tool}; create data bag item " \
          "#{VERSIONS_DATA_BAG}/#{tool} (#{e.class}: #{e.message})"
  end
end

# -------------------------------------------------------------------------------
# DSL extension -- expose pinned_version inside recipes and resources
# -------------------------------------------------------------------------------

Chef::DSL::Recipe.include(MunchboxLibPinnedVersion)
Chef::Resource.include(MunchboxLibPinnedVersion)
