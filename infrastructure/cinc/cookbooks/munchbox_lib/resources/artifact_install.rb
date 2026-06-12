# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Resource:: munchbox_lib_artifact
#
# Generic download-verify-install for an external artifact. The caller supplies
# the URL and the validation strategy; this resource fetches, verifies the
# checksum BEFORE installing (the integrity gate), and installs by format.
# Nothing here is service-specific -- service cookbooks build their own URL and
# keep their own user/dir/systemd/restart wiring.
#
# Validation (pick one):
#   checksum  - a literal sha256 the caller already knows (pinned/recorded).
#   sums_url  - URL of a "<sha>  <file>" SHA256SUMS body; the sha for
#               sums_filename (default: basename of source) is looked up.
#
# Idempotency: not_if_installed is a shell guard that, when it exits 0, means
# the wanted version is already present -- download/verify/install all skip.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_lib_artifact

property :source,           String, required: true
property :format,           Symbol, equal_to: %i(zip deb), required: true
property :cache_path,       String
property :not_if_installed, [String, nil]

# --- validation strategy (exactly one) ---
property :checksum,      [String, nil]
property :sums_url,      [String, nil]
property :sums_filename, [String, nil]

# --- :zip install target ---
property :bin_dir, String, default: '/usr/local/bin'

# --- :deb install ---
property :package_name,    [String, nil]
property :package_version, [String, nil]

default_action :install

action :install do
  raise "munchbox_lib_artifact[#{new_resource.name}]: set checksum or sums_url" if new_resource.checksum.nil? && new_resource.sums_url.nil?

  cache     = new_resource.cache_path || "/var/cache/#{::File.basename(new_resource.source)}"
  sums_path = "#{cache}.SHA256SUMS"
  guard     = new_resource.not_if_installed

  # --- not_if as a block so an absent guard means "always run" ---
  already_installed = proc { !guard.nil? && shell_out(guard).exitstatus.zero? }

  # --- fetch the SHA256SUMS body when validating that way ---
  if new_resource.sums_url
    remote_file sums_path do
      source new_resource.sums_url
      mode   '0644'
      not_if(&already_installed)
    end
  end

  remote_file cache do
    source new_resource.source
    owner  'root'
    group  'root'
    mode   '0644'
    not_if(&already_installed)
  end

  # --- integrity gate: verify the downloaded file before any install step ---
  ruby_block "verify #{::File.basename(cache)}" do
    block do
      expected = new_resource.checksum
      if expected.nil?
        fname    = new_resource.sums_filename || ::File.basename(new_resource.source)
        expected = MunchboxLibCookbook::Artifact.sha256_for(::File.read(sums_path), fname)
      end
      MunchboxLibCookbook::Artifact.verify!(cache, expected)
    end
    not_if(&already_installed)
  end

  case new_resource.format
  when :zip
    package 'unzip'

    execute "install #{::File.basename(cache)}" do
      command "unzip -o #{cache} -d #{new_resource.bin_dir} && rm -f #{cache}"
      not_if(&already_installed)
    end
  when :deb
    dpkg_package new_resource.package_name do
      source  cache
      version new_resource.package_version
      action  :install
      not_if(&already_installed)
    end
  end
end
