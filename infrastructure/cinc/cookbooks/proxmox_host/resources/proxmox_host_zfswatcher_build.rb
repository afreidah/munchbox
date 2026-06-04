# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: proxmox_host
# Resource:: proxmox_host_zfswatcher_build
#
# Idempotent build of rouben/zfswatcher from source. Installs the go
# toolchain + git + build-essential, clones the repo at a pinned ref,
# runs `go build`, and drops the resulting binary at bin_path with mode
# 0755. Records the resolved commit at <install_dir>/.commit so a
# subsequent converge skips the full clone+build when the binary already
# matches the pinned ref.
#
# Properties:
#   repo_url     - git URL to clone (default rouben/zfswatcher on github).
#   ref          - Branch / tag / commit to check out (default master).
#   install_dir  - Cookbook-owned tree for clone + build artifacts.
#   src_dir      - Working dir inside install_dir (default <install_dir>/src).
#   bin_path     - Final binary location (default /opt/zfswatcher/zfswatcher).
#   build_cmd    - go build invocation; CWD is src_dir.
#   packages     - Apt packages to install (toolchain + git).
# -------------------------------------------------------------------------------

unified_mode true

provides :proxmox_host_zfswatcher_build

property :repo_url,    String, default: 'https://github.com/rouben/zfswatcher.git'
property :ref,         String, default: 'master'
property :install_dir, String, default: '/opt/zfswatcher'
property :src_dir,     String, default: '/opt/zfswatcher/src'
property :bin_path,    String, default: '/opt/zfswatcher/zfswatcher'
property :build_cmd,   String, default: 'GO111MODULE=off GOPATH="$(pwd)/golibs:$(go env GOPATH)" go build -o zfswatcher .'
property :packages,    Array,  default: %w(git golang-go build-essential)

default_action :install

action :install do
  munchbox_base_apt_lock_wait "proxmox_host_zfswatcher_build_#{new_resource.name}"

  apt_package new_resource.packages do
    action :install
  end

  directory new_resource.install_dir do
    owner 'root'
    group 'root'
    mode  '0755'
  end

  src         = new_resource.src_dir
  bin         = new_resource.bin_path
  ref         = new_resource.ref
  commit_path = ::File.join(new_resource.install_dir, '.commit')

  # --- Initial clone (idempotent: only fires if src_dir is empty / missing) ---
  execute "git clone zfswatcher (#{ref})" do
    command "git clone #{new_resource.repo_url} #{src}"
    user    'root'
    not_if  { ::File.directory?(::File.join(src, '.git')) }
  end

  # --- Refresh remote refs + checkout the pinned ref (handles bumps over time) ---
  execute "git fetch + checkout zfswatcher #{ref}" do
    command "cd #{src} && git fetch --all --tags && git checkout #{ref} && git reset --hard #{ref}"
    user    'root'
    # --- Skip when the recorded commit matches the resolved ref ---
    not_if  "test -f #{commit_path} && " \
            "test \"$(cat #{commit_path})\" = \"$(cd #{src} && git rev-parse #{ref} 2>/dev/null)\""
    notifies :run, "execute[go build zfswatcher (#{ref})]", :immediately
  end

  execute "go build zfswatcher (#{ref})" do
    command "cd #{src} && #{new_resource.build_cmd} && install -m 0755 #{src}/zfswatcher #{bin} && " \
            "git rev-parse HEAD > #{commit_path}"
    user    'root'
    action  :nothing
  end

  # --- Initial build when the binary is absent (handles first converge: clone done above, no notify path) ---
  execute "initial build zfswatcher (#{ref})" do
    command "cd #{src} && #{new_resource.build_cmd} && install -m 0755 #{src}/zfswatcher #{bin} && " \
            "git rev-parse HEAD > #{commit_path}"
    user    'root'
    not_if { ::File.exist?(bin) }
  end
end
