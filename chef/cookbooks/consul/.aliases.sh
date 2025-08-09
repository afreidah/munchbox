#!/bin/bash

# ---------------------------------------------------------------------------------
# aliases.sh
#
#  This file contains aliases for common tasks in this development envrionment.
#
#  Simplifies running things to iterate quickly because the commands are long.
#  ---------------------------------------------------------------------------------

alias lint="bundle exec rake lint"
alias fix="bundle exec rake lint:cookstyle_a"
alias spec="bundle exec rake spec"
alias fresh="rm -rf .kitchen/ && bundle exec berks install"
alias rake="bundle exec rake"
alias converge="bundle exec kitchen converge"
alias verify="bundle exec kitchen verify"
alias destroy="bundle exec kitchen destroy"
alias list="bundle exec kitchen list"

export DOCKER_BUILDKIT=0
