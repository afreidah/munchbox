# knife.rb

# Local paths to your cookbooks and data bags
cookbook_path [
  File.expand_path('cookbooks', __dir__),
  File.expand_path('community-cookbooks', __dir__)
]

data_bag_path File.expand_path('data_bags', __dir__)

encrypted_data_bag_secret File.expand_path('encrypted_data_bag_secret', __dir__)

# Optional: Silence SSL warnings if not using Chef server
ssl_verify_mode :verify_none
