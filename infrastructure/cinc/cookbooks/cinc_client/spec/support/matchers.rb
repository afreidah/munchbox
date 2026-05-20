# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Custom rspec/chefspec matchers
#
# ChefSpec's auto-generated matchers call `ChefSpec::Coverage.cover!` on
# the resource, which is how the coverage tracker decides a resource was
# tested. Resources declared with `action :nothing` never get hit by an
# action-named matcher, so they always show up as untouched.
#
# `do_nothing` is a thin matcher that calls cover! and asserts the
# resource's action is :nothing.
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
