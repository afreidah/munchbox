# -------------------------------------------------------------------------------
# Cookbook:: cni
# Makefile -- delegates to cinc-workstation tools.
# -------------------------------------------------------------------------------

CHEF      := /usr/local/bin/chef
COOKSTYLE := /usr/local/bin/cookstyle
KITCHEN   := /usr/local/bin/kitchen

.PHONY: help tools test lint kitchen create converge verify login destroy

help:
	@echo "make tools     - install cinc-workstation + libvirt/vagrant stack (one-time host setup)"
	@echo "make lint      - cookstyle (rubocop with chef cops)"
	@echo "make test      - chefspec/rspec unit tests"
	@echo ""
	@echo "Kitchen lifecycle:"
	@echo "  make create    - provision the VM"
	@echo "  make converge  - run cinc-client on the VM"
	@echo "  make verify    - run inspec controls against the converged VM"
	@echo "  make login     - ssh into the VM"
	@echo "  make destroy   - tear the VM down"
	@echo "  make kitchen   - create + converge + verify + destroy in one go"

tools:
	../../../scripts/kitchen-debian.sh

lint:
	$(COOKSTYLE) .

test:
	$(CHEF) exec rspec spec/

kitchen:
	$(KITCHEN) test

create:
	$(KITCHEN) create

converge:
	$(KITCHEN) converge

verify:
	$(KITCHEN) verify

login:
	$(KITCHEN) login

destroy:
	$(KITCHEN) destroy
