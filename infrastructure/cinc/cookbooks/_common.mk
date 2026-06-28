# -------------------------------------------------------------------------------
# Shared cookbook Makefile
#
# Standard lint / test / kitchen-lifecycle targets for every full-kitchen
# Munchbox cookbook. Cookbook Makefiles are thin wrappers: `include ../_common.mk`.
# Library-only cookbooks (no kitchen) keep their own minimal Makefile.
# -------------------------------------------------------------------------------

CHEF      := /usr/local/bin/chef
COOKSTYLE := /usr/local/bin/cookstyle
KITCHEN   := /usr/local/bin/kitchen

.PHONY: help tools test lint verify kitchen create converge kitchen-verify login destroy cache-clean

help:
	@echo "make tools     - install cinc-workstation + libvirt/vagrant stack (one-time host setup)"
	@echo "make lint      - cookstyle (rubocop with chef cops)"
	@echo "make test      - chefspec/rspec unit tests"
	@echo "make verify    - lint + test (the CI check)"
	@echo ""
	@echo "Kitchen lifecycle:"
	@echo "  make create        - provision the VM"
	@echo "  make converge      - run cinc-client on the VM"
	@echo "  make kitchen-verify- run inspec controls against the converged VM"
	@echo "  make login         - ssh into the VM"
	@echo "  make destroy       - tear the VM down"
	@echo "  make kitchen       - create + converge + verify + destroy in one go"

tools:
	../../../scripts/kitchen-debian.sh

lint:
	$(COOKSTYLE) .

test:
	$(CHEF) exec rspec spec/

# --- CI check: cookstyle + unit tests (kitchen is separate; see kitchen-verify) ---
verify: lint test

# --- Bust berkshelf cache for locally-sourced cookbooks + drop lockfile so edits
#     to munchbox_base / munchbox_lib ship into kitchen instead of being served
#     stale from ~/.berkshelf when the cookbook version hasn't bumped ---
cache-clean:
	rm -rf $(HOME)/.berkshelf/cookbooks/munchbox_base-* $(HOME)/.berkshelf/cookbooks/munchbox_lib-* Berksfile.lock

kitchen: cache-clean
	$(KITCHEN) test

create:
	$(KITCHEN) create

converge: cache-clean
	$(KITCHEN) converge

kitchen-verify:
	$(KITCHEN) verify

login:
	$(KITCHEN) login

destroy:
	$(KITCHEN) destroy
