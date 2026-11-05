# phone-admin / ios — run `make help` (or `make ios-help` from the repo root).
#
# View (AirPlay mirroring) + manage (libimobiledevice over USB) your own iPhone. No remote control:
# iOS gives an outside computer no way to inject touches or keys.
#
# Several iPhones attached:  make info UDID=00008110-000A1B2C3D4E5F6A
# Extra uxplay flags:        make mirror OPTS="-fs -fps 60"
# Relative paths (DIR=, DEST=, FILE=, IPA=) are relative to where you ran make, and so are the defaults.

SHELL := /bin/bash

# Parameters are read only from the make command line (make mirror NAME=Desk). A variable that merely
# happens to be exported in your shell (NAME=<hostname> on WSL, …) must not change a target.
arg  = $(if $(filter command line,$(origin $1)),$($1))
q    = '$(subst ','\'',$1)'
qarg = $(if $(call arg,$1),$(call q,$(call arg,$1)))
OPTS := $(call arg,OPTS)
NAME := $(or $(call arg,NAME),phone-admin)
# The root Makefile passes CALLER=<its dir>; run from here, it is this dir.
CALLER := $(or $(call arg,CALLER),$(CURDIR))
RUN  := cd $(call q,$(CALLER)) &&
M    := $(RUN) $(call q,$(CURDIR)/scripts/manage-cheatsheet.sh)

ifdef UDID
export UDID
endif
export NAME

.PHONY: help install install-mirror install-manage install-pmd3 doctor mirror mirror-fs devices pair \
        unpair info apps install-ipa backup backup-full backup-info screenshot dev-mode mount-ddi \
        mount umount photos syslog lint

help: ## show this help
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-15s %s\n", $$1, $$2}'

install: ## install uxplay + libimobiledevice + ideviceinstaller + ifuse (Ubuntu packages)
	scripts/install.sh

install-mirror: ## mirroring only (uxplay, GStreamer, Avahi)
	scripts/install.sh --no-manage

install-manage: ## management only (libimobiledevice, ideviceinstaller, ifuse)
	scripts/install.sh --no-mirror

install-pmd3: ## optional pymobiledevice3 via pipx (screenshots on iOS 17+)
	scripts/install.sh --no-mirror --no-manage --pymobiledevice3

doctor: ## check tools, services, pairing and what the iPhone's iOS version allows
	$(M) doctor

mirror: ## start the AirPlay receiver; iPhone → Control Center → Screen Mirroring (view only)
	scripts/mirror.sh $(OPTS)

mirror-fs: ## same, full screen
	scripts/mirror.sh -fs $(OPTS)

devices: ## UDIDs and names of iPhones on USB
	$(M) devices

pair: ## pair with this PC (tap "Trust" + enter passcode on the iPhone)
	$(M) pair

unpair: ## remove this PC's pairing from the iPhone
	$(M) unpair

info: ## name, model, iOS version, battery, storage, Developer Mode
	$(M) info

apps: ## user-installed apps (FILTER=text to grep)
	$(M) apps $(call qarg,FILTER)

install-ipa: ## install IPA=path/to/app.ipa (must be signed for this device)
	@test -n $(call q,$(call arg,IPA)) || { echo "usage: make install-ipa IPA=path/to/app.ipa"; exit 2; }
	$(M) install $(call qarg,IPA)

backup: ## incremental backup into DIR (default ./backups); checks free space first (FORCE=1 skips)
	$(M) backup $(call q,$(or $(call arg,DIR),backups))

backup-full: ## full backup into DIR (default ./backups)
	$(RUN) FULL=1 $(call q,$(CURDIR)/scripts/manage-cheatsheet.sh) backup $(call q,$(or $(call arg,DIR),backups))

backup-info: ## last backup in DIR (default ./backups)
	$(M) backup-info $(call q,$(or $(call arg,DIR),backups))

screenshot: ## screenshot to FILE (needs Developer Mode; see docs/MANAGE.md)
	$(M) screenshot $(call qarg,FILE)

dev-mode: ## iOS 16+: reveal the Developer Mode switch (you enable it on the phone)
	$(M) dev-mode

mount-ddi: ## mount the Developer Disk Image (pymobiledevice3)
	$(M) mount-ddi

mount: ## mount the camera roll/media area at DIR (default ./iphone-media)
	$(M) mount $(call q,$(or $(call arg,DIR),iphone-media))

umount: ## unmount DIR (default ./iphone-media)
	$(M) umount $(call q,$(or $(call arg,DIR),iphone-media))

photos: ## copy new photos/videos to DEST (default ./photos); never deletes
	$(M) photos $(call q,$(or $(call arg,DEST),photos))

syslog: ## live device log (MATCH=text to filter)
	$(M) syslog $(call qarg,MATCH)

lint: ## shellcheck the scripts (falls back to the koalaman/shellcheck Docker image)
	@if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh; \
	else echo "shellcheck not installed, using Docker"; \
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt koalaman/shellcheck:stable scripts/*.sh; fi
