# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Makefile
#
# Standard targets every Munchbox cookbook ships with.
#   make test  - run rspec (chefspec for cookbooks that have recipes/resources)
#   make lint  - run cookstyle (rubocop with chef cops)
# -------------------------------------------------------------------------------

.PHONY: help test lint deps

help:
	@echo "make test  - run rspec"
	@echo "make lint  - run cookstyle"
	@echo "make deps  - bundle install"

deps:
	bundle install

test:
	bundle exec rspec spec/

lint:
	bundle exec cookstyle .
