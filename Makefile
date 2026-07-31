# EnigmaOS top-level Makefile
.PHONY: help prepare check iso iso-docker clean package-list

ROOT := $(abspath .)

help:
	@echo "EnigmaOS targets:"
	@echo "  make prepare     - sync branding into archiso profile"
	@echo "  make check       - validate repository structure"
	@echo "  make iso-docker  - build ISO via Arch Docker container (recommended)"
	@echo "  make iso         - build ISO natively (requires root + archiso)"
	@echo "  make clean       - remove work/ and out/"

prepare:
	./scripts/build/prepare-profile.sh

check:
	./scripts/dev/sync-airootfs-check.sh

iso: prepare
	sudo ./scripts/build/build-iso.sh

iso-docker: prepare
	./scripts/build/docker-build-iso.sh

package-list:
	@wc -l packages.x86_64
	@echo "Unique package names:"
	@grep -vE '^\s*#|^\s*$$' packages.x86_64 | sort -u | wc -l

clean:
	rm -rf work out
