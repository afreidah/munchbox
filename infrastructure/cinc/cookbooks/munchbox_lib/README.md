# munchbox_lib

Library-only cookbook. Holds shared helpers used by every other cookbook in
this repo. No recipes, no resources, no attributes — just `libraries/`.

Add to your cookbook by adding the dependency in `metadata.rb`:

```ruby
depends 'munchbox_lib'
```

## Helpers

### `cookbook`

Returns the calling cookbook's name by parsing its own `metadata.rb`. Lets
the literal cookbook name live in exactly one place per cookbook.

Available as a bare method everywhere: recipes, resources, templates, AND
attribute files (chef >= 12 loads libraries before attributes, and `Chef::Node`
is extended so the bare `cookbook` method resolves inside attribute files too).

```ruby
# attributes/default.rb
default[cookbook]['svc_user'] = 'alice'

# recipes/server.rb
user node[cookbook]['svc_user'] do
  action :create
end
```

Or via the full module path from anywhere else:

```ruby
MunchboxLibCookbook::Helpers.cookbook
```

Results are memoized for the chef-client run lifetime — the first call walks
the directory tree to find `metadata.rb` and parses it; every subsequent call
from the same file is a hash lookup.

## Development

```
make lint    # cookstyle
make test    # rspec
```
