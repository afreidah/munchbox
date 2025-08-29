#!/bin/bash

# ---------------------------------------------------------------------------------
# aliases.sh
#
#  This file contains aliases for common tasks in this development envrionment.
#
#  Simplifies running things to iterate quickly because the commands are long.
#  ---------------------------------------------------------------------------------

# --- Kitchen aliases ---
alias kl='bundle exec kitchen list'
alias converge='bundle exec kitchen converge'
alias destroy='bundle exec kitchen destroy'
alias verify='bundle exec kitchen verify'

# -- Rake and other aliases ---
alias rake='bundle exec rake'
alias lint='bundle exec rake lint'
alias fix='bundle exec rake lint:fix'
alias fresh='bundle exec rake berks:fresh'
alias spec='bundle exec rake spec'
alias clean='rm -rf Berksfile.lock berks-vendor; bundle exec berks install; bundle exec berks vendor'
alias static='bundle exec rake lint && bundle exec rake spec'

# -- Chef/Ubuntu build aliases ---
alias converge1='bundle exec kitchen converge openbao-1-ubuntu-2404'
alias destroy1='bundle exec kitchen destroy openbao-1-ubuntu-2404'
alias verify1='bundle exec kitchen verify openbao-1-ubuntu-2404'
alias login1='bundle exec kitchen login openbao-1-ubuntu-2404'

alias converge2='bundle exec kitchen converge openbao-2-ubuntu-2404'
alias destroy2='bundle exec kitchen destroy openbao-2-ubuntu-2404'
alias verify2='bundle exec kitchen verify openbao-2-ubuntu-2404'
alias login2='bundle exec kitchen login openbao-2-ubuntu-2404'

alias converge3='bundle exec kitchen converge openbao-3-ubuntu-2404'
alias destroy3='bundle exec kitchen destroy openbao-3-ubuntu-2404'
alias verify3='bundle exec kitchen verify openbao-3-ubuntu-2404'
alias login3='bundle exec kitchen login openbao-3-ubuntu-2404'
