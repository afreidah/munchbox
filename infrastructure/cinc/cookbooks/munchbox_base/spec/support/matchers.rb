# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Custom rspec/chefspec matchers
#
# ChefSpec's auto-generated matchers (install_package, enable_service, ...)
# call `ChefSpec::Coverage.cover!` on the resource, which is how the coverage
# tracker decides a resource was tested. Resources declared with `action
# :nothing` (services declared for notifies, apt_update subscribed to a repo)
# never get hit by an action-named matcher, so they always show up as
# untouched.
#
# `do_nothing` here is a thin matcher that calls cover! and then asserts the
# resource's action is :nothing. Use it on the chef_run resource accessor:
#
#   expect(chef_run.service('ssh')).to do_nothing
#   expect(chef_run.apt_update('munchbox-apt-update')).to do_nothing
# -------------------------------------------------------------------------------

RSpec::Matchers.define :do_nothing do
  match do |resource|
    next false unless resource

    ChefSpec::Coverage.cover!(resource)
    actions = Array(resource.action)
    actions.include?(:nothing)
  end

  failure_message do |resource|
    if resource.nil?
      'expected a chef resource but got nil'
    else
      "expected #{resource} to have action :nothing, got #{Array(resource.action).inspect}"
    end
  end
end
