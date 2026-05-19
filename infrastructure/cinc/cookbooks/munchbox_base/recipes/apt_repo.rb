# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: apt_repo
#
# Registers the munchbox aptly repository + signing key on the node.
# -------------------------------------------------------------------------------

munchbox_base_apt_repo node[cookbook]['apt_repo']['name'] do
  uri          node[cookbook]['apt_repo']['uri']
  distribution node[cookbook]['apt_repo']['distribution']
  components   node[cookbook]['apt_repo']['components']
  key_url      node[cookbook]['apt_repo']['key_url']
end
