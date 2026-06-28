# -------------------------------------------------------------------------------
# Cookbook:: munchbox_lib
# Makefile
#
# Standard targets every Munchbox cookbook ships with. Library-only cookbook
# (no kitchen), so verify is just lint + test.
#   make test    - run rspec
#   make lint    - run cookstyle (rubocop with chef cops)
#   make verify  - lint + test (the CI check)
# -------------------------------------------------------------------------------

.PHONY: help test lint verify

help:
	@echo "make test    - run rspec"
	@echo "make lint    - run cookstyle"
	@echo "make verify  - lint + test (the CI check)"

test:
	chef exec rspec spec/

lint:
	cookstyle .

verify: lint test
