# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
#
# Project: Munchbox / Author: Alex Freidah
#
# Library-only cookbook. Holds shared helpers used by every other cookbook
# in this repo (cookbook_name lookup, etc). No recipes, no resources, no
# attributes - just `libraries/`.
# -------------------------------------------------------------------------------

name             'munchbox_lib'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'Shared helper library for Munchbox cookbooks'
version          '0.1.0'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'
source_url       'https://github.com/afreidah/munchbox'
