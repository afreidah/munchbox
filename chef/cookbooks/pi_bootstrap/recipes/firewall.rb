# frozen_string_literal: true

include_recipe 'firewall'

firewall_rule 'loopback' do
  protocol :all
  source   '127.0.0.1'
  command  :allow
end

firewall_rule 'ssh' do
  port    22
  source  '192.168.1.0/24'
  command :allow
end
