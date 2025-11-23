# consul::mgmt_token_file
mgmt_item = data_bag_item('consul', 'management') rescue nil
raise 'consul/management data bag missing' unless mgmt_item

mgmt_token = mgmt_item['token'] || mgmt_item['SecretID']
raise 'management token not found in data bag' if mgmt_token.to_s.empty?

directory '/opt/consul' do
  owner 'root'
  group 'root'
  mode  '0750'
end

file '/opt/consul/consul_mgmt.token' do
  content   "#{mgmt_token}\n"
  owner     'root'
  group     'root'
  mode      '0600'
  sensitive true
end
