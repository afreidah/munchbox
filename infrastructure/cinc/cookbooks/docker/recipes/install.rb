# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: docker
# Recipe:: install
#
# Adds the upstream Docker apt repo, installs Docker CE, and (by
# default) puts the nomad system user in the docker group so the nomad
# docker driver can launch containers without root.
# -------------------------------------------------------------------------------

install = node[cookbook]['install']

docker_install 'docker' do
  packages          install['packages']
  remove_packages   install['remove_packages']
  prereq_packages   install['prereq_packages']
  key_url           install['key_url']
  repo_uri          install['repo_uri']
  repo_component    install['repo_component']
  add_user_to_group install['add_user_to_group']
  dependent_service install['dependent_service']
end
