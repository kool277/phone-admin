# ios-viewer — run `make help`.
#
# View (AirPlay mirroring) + manage (libimobiledevice over USB) your own iPhone. No remote control:
# iOS gives an outside computer no way to inject touches or keys.
#
# Several iPhones attached:  make info UDID=00008110-000A1B2C3D4E5F6A
# Extra uxplay flags:        make mirror OPTS="-fs -fps 60"

SHELL := /bin/bash
OPTS  ?=
NAME  ?= ios-viewer
M     := scripts/manage-cheatsheet.sh

ifdef UDID
export UDID
endif
export NAME

.PHONY: help install install-mirror install-manage install-pmd3 doctor mirror mirror-fs devices pair \
        unpair info apps install-ipa backup backup-full backup-info screenshot dev-mode mount-ddi \
        mount umount syslog lint

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
	$(M) apps $(FILTER)

install-ipa: ## install IPA=path/to/app.ipa (must be signed for this device)
	@test -n "$(IPA)" || { echo "usage: make install-ipa IPA=path/to/app.ipa"; exit 2; }
	$(M) install "$(IPA)"

backup: ## incremental backup into DIR (default ./backups)
	$(M) backup $(or $(DIR),backups)

backup-full: ## full backup into DIR (default ./backups)
	FULL=1 $(M) backup $(or $(DIR),backups)

backup-info: ## last backup in DIR (default ./backups)
	$(M) backup-info $(or $(DIR),backups)

screenshot: ## screenshot to FILE (needs Developer Mode; see docs/MANAGE.md)
	$(M) screenshot $(FILE)

dev-mode: ## iOS 16+: reveal the Developer Mode switch (you enable it on the phone)
	$(M) dev-mode

mount-ddi: ## mount the Developer Disk Image (pymobiledevice3)
	$(M) mount-ddi

mount: ## mount the camera roll/media area at DIR (default ./iphone-media)
	$(M) mount $(or $(DIR),iphone-media)

umount: ## unmount DIR (default ./iphone-media)
	$(M) umount $(or $(DIR),iphone-media)

syslog: ## live device log (MATCH=text to filter)
	$(M) syslog $(MATCH)

lint: ## shellcheck the scripts
	shellcheck scripts/*.sh
