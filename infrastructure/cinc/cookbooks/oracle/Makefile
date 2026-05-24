# -------------------------------------------------------------------------------
# Cookbook:: oracle
# Makefile
# -------------------------------------------------------------------------------

CHEF      := /usr/local/bin/chef
COOKSTYLE := /usr/local/bin/cookstyle
KITCHEN   := /usr/local/bin/kitchen

.PHONY: help tools test lint kitchen create converge verify login destroy cache-clean

help:
	@echo "make tools     - install cinc-workstation + libvirt/vagrant stack"
	@echo "make lint      - cookstyle"
	@echo "make test      - chefspec/rspec"
	@echo "make kitchen   - full kitchen cycle (NOTE: kitchen not configured for oracle yet -- requires consul running with valid token)"

tools:
	../../scripts/kitchen/debian.sh

lint:
	$(COOKSTYLE) .

test:
	$(CHEF) exec rspec spec/

# --- Bust berkshelf cache for locally-sourced cookbooks + drop lockfile so edits to munchbox_base / munchbox_lib actually ship into kitchen instead of being served stale from ~/.berkshelf when the cookbook version hasn't bumped ---
cache-clean:
	rm -rf $(HOME)/.berkshelf/cookbooks/munchbox_base-* $(HOME)/.berkshelf/cookbooks/munchbox_lib-* Berksfile.lock

kitchen: cache-clean
	$(KITCHEN) test

create:
	$(KITCHEN) create

converge: cache-clean
	$(KITCHEN) converge

verify:
	$(KITCHEN) verify

login:
	$(KITCHEN) login

destroy:
	$(KITCHEN) destroy
