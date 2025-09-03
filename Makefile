# ------------------------------------------------------------------------------
# Root Makefile — Monorepo task router (local + CI)
# ------------------------------------------------------------------------------

.PHONY: all tf cdktf nomad chef docker

all: tf cdktf nomad chef

tf:
	@echo "[tf] no plain Terraform tree detected; using Tofu/CDKTF where applicable"

cdktf:
	$(MAKE) -C cdktf/cloudflare test || true
	$(MAKE) -C cdktf/munchbox-core test || true

nomad:
	$(MAKE) -C cdktf/munchbox-core/nomad-jobs validate

chef:
	$(MAKE) -C chef lint
	$(MAKE) -C chef spec

docker:
	$(MAKE) -C docker/deluge-vpn build

