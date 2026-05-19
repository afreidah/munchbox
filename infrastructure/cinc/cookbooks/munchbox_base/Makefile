# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Makefile
#
# All targets delegate to cinc-workstation tools wrapped in /usr/local/bin
# (which env -i to isolate from any RVM/bundler pollution). Bootstrap the
# toolchain once with `make tools` -- after that everything just works.
#
#   make tools    - install cinc-workstation + libvirt/vagrant stack
#   make lint     - cookstyle
#   make test     - chefspec/rspec via chef's bundled rspec
#   make kitchen  - full test-kitchen run (create + converge + verify + destroy)
#   make verify   - kitchen verify only (VM already up)
#   make destroy  - tear down the kitchen VM
# -------------------------------------------------------------------------------

# --- Absolute paths to the cinc wrappers so RVM/rbenv PATH ordering can't win ---
CHEF      := /usr/local/bin/chef
COOKSTYLE := /usr/local/bin/cookstyle
KITCHEN   := /usr/local/bin/kitchen

.PHONY: help tools test lint kitchen create converge verify login destroy

help:
	@echo "make tools     - install cinc-workstation + libvirt/vagrant stack (one-time host setup)"
	@echo "make lint      - cookstyle (rubocop with chef cops)"
	@echo "make test      - chefspec/rspec unit tests"
	@echo ""
	@echo "Kitchen lifecycle (run in order, or use 'make kitchen' to do all in one shot):"
	@echo "  make create    - provision the VM (vagrant up)"
	@echo "  make converge  - run cinc-client on the VM"
	@echo "  make verify    - run inspec controls against the converged VM"
	@echo "  make login     - ssh into the VM"
	@echo "  make destroy   - tear the VM down"
	@echo ""
	@echo "  make kitchen   - create + converge + verify + destroy in one go"

tools:
	../../scripts/kitchen/debian.sh

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
