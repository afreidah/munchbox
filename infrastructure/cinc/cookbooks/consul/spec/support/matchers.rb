# frozen_string_literal: true

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
