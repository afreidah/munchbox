# -------------------------------------------------------------------------------
# Cookbook:: docker
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
	@echo "make kitchen   - full kitchen cycle"

tools:
	../../../scripts/kitchen-debian.sh

lint:
	$(COOKSTYLE) .

test:
	$(CHEF) exec rspec spec/

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
