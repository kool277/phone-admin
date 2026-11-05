# phone-admin: your own Android phone and iPhone from Ubuntu. Run `make help`.
#
#   make android-<target>   runs <target> in android/   (list: make android-help)
#   make ios-<target>       runs <target> in ios/       (list: make ios-help)
#
# Variables pass through:  make android-mirror SERIAL=192.168.1.42:5555
#                          make ios-backup UDID=00008110-000A1B2C3D4E5F6A DIR=/media/backup
# Relative paths (DEST=photos, APK=app.apk, …) are relative to where you ran make, not android/ or ios/.

SHELL := /bin/bash

.PHONY: help install doctor devices lint

help: ## show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'
	@echo
	@echo "  make android-<target>  Android (scrcpy, adb, RustDesk): make android-help"
	@echo "  make ios-<target>      iPhone (uxplay, libimobiledevice): make ios-help"

install: ## install both toolchains: scrcpy + adb, then uxplay + libimobiledevice
	$(MAKE) -C android install
	$(MAKE) -C ios install

doctor: ## check both toolchains and every attached phone
	@echo "== Android"; $(MAKE) -s --no-print-directory -C android doctor || true
	@echo; echo "== iPhone"; $(MAKE) -s --no-print-directory -C ios doctor || true

devices: ## Android devices (adb) and iPhones (USB)
	@echo "== Android"; if command -v adb >/dev/null; then adb devices -l | tail -n +2; else echo "adb not installed"; fi
	@echo "== iPhone";  if command -v idevice_id >/dev/null; then ios/scripts/manage-cheatsheet.sh devices; else echo "libimobiledevice not installed"; fi

lint: ## shellcheck all scripts
	$(MAKE) --no-print-directory -C android lint
	$(MAKE) --no-print-directory -C ios lint

# CALLER tells the sub-make where relative paths start (make -C changes the directory and $PWD).
android-%:
	@$(MAKE) --no-print-directory -C android $* CALLER='$(subst ','\'',$(CURDIR))'

ios-%:
	@$(MAKE) --no-print-directory -C ios $* CALLER='$(subst ','\'',$(CURDIR))'
