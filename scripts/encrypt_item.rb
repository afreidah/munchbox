# encrypt_item.rb
# --------------------------------------------------------------------
# Offline-encrypt a Chef data bag item for chef-solo.
# Usage: ruby encrypt_item.rb <bag> <item_plain_json> <secret_path> <out_encrypted_json>
# Example:
#   ruby encrypt_item.rb consul nomad_server.plain.json /var/chef/data_bag_key /var/chef/data_bags/consul/nomad_server.json
# --------------------------------------------------------------------
require 'json'
require 'chef/encrypted_data_bag_item'

bag, in_file, secret_path, out_file = ARGV
abort "Usage: #{__FILE__} <bag> <plain.json> <secret_path> <out.json>" unless out_file

plain  = JSON.parse(File.read(in_file))
secret = Chef::EncryptedDataBagItem.load_secret(secret_path)
enc    = Chef::EncryptedDataBagItem.encrypt_data_bag_item(plain, secret)

File.write(out_file, JSON.pretty_generate(enc))
puts "Wrote encrypted item to #{out_file}"
