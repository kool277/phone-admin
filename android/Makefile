# phone-admin / android — run `make help` (or `make android-help` from the repo root).
#
# Target one device among several:  make mirror SERIAL=192.168.1.42:5555
# Extra scrcpy flags:               make mirror OPTS="--max-size=1600 --turn-screen-off"
# Relative paths (APK=, DEST=, FILE=) are relative to where you ran make, and so are the defaults.

SHELL := /bin/bash

# Parameters are read only from the make command line (make wireless PORT=5555). A variable that
# merely happens to be exported in your shell (PORT=3000 for a web app, …) must not change a target.
arg  = $(if $(filter command line,$(origin $1)),$($1))
q    = '$(subst ','\'',$1)'
qarg = $(if $(call arg,$1),$(call q,$(call arg,$1)))
OPTS := $(call arg,OPTS)
# The root Makefile passes CALLER=<its dir>; run from here, it is this dir.
CALLER := $(or $(call arg,CALLER),$(CURDIR))
RUN  := cd $(call q,$(CALLER)) &&
S    := $(call q,$(CURDIR)/scripts)

# adb and scrcpy both honor ANDROID_SERIAL.
ifneq ($(call arg,SERIAL),)
export ANDROID_SERIAL := $(SERIAL)
endif

.PHONY: help install install-apt devices info mirror mirror-usb mirror-wifi mirror-tcpip \
        desktop record pair connect wireless disconnect install-apk rustdesk-android \
        rustdesk-perms vm-up vm-mirror vm-down vm-status photos doctor lint

help: ## show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-17s %s\n", $$1, $$2}'

install: ## install scrcpy + adb (official release, bundles current adb)
	scripts/install.sh

install-apt: ## install Ubuntu-packaged scrcpy/adb instead (older)
	scripts/install.sh --apt

doctor: ## check adb/scrcpy, the adb package conflict, devices and authorization
	scripts/adb-cheatsheet.sh doctor

devices: ## list attached devices
	adb devices -l

info: ## model / Android version / battery / storage of the device
	scripts/adb-cheatsheet.sh info

mirror: ## mirror + control the only (or SERIAL) device
	scrcpy $(OPTS)

mirror-usb: ## mirror the USB-attached device
	scrcpy -d $(OPTS)

mirror-wifi: ## mirror the device connected over TCP/IP
	scrcpy -e $(OPTS)

mirror-tcpip: ## phone on USB → switch it to Wi-Fi and mirror wirelessly (or IP=a.b.c.d)
	scrcpy --tcpip$(if $(call arg,IP),=$(call q,$(IP))) $(OPTS)

desktop: ## separate virtual display on the phone (Android 10+), SIZE=1920x1080
	scrcpy --new-display=$(call q,$(or $(call arg,SIZE),1920x1080)) $(OPTS)

record: ## record screen to FILE without opening a window (Ctrl+C to stop)
	$(RUN) scrcpy --no-window --record=$(or $(call qarg,FILE),record-$$(date +%Y%m%d-%H%M%S).mp4) $(OPTS)

pair: ## Android 11+ wireless pairing: ADDR=ip:pairport [CODE=123456]
	scripts/wireless.sh pair $(call q,$(call arg,ADDR)) $(call qarg,CODE)

connect: ## Android 11+ wireless connect: ADDR=ip:port
	scripts/wireless.sh connect $(call q,$(call arg,ADDR))

wireless: ## any Android: phone on USB → adb over Wi-Fi on PORT (default 5555)
	scripts/wireless.sh tcpip $(call qarg,PORT)

disconnect: ## drop TCP/IP adb connections (ADDR=ip:port for just one)
	scripts/wireless.sh disconnect $(call qarg,ADDR)

install-apk: ## install APK=path/to/app.apk (keeps app data)
	@test -n $(call q,$(call arg,APK)) || { echo "usage: make install-apk APK=path/to/app.apk"; exit 2; }
	$(RUN) $(S)/adb-cheatsheet.sh install $(call qarg,APK)

rustdesk-android: ## download + install latest RustDesk APK matching the phone's CPU
	scripts/adb-cheatsheet.sh rustdesk-apk

rustdesk-perms: ## optional: battery exemption via adb; reports Input Control (you turn it on on the phone)
	scripts/adb-cheatsheet.sh rustdesk-perms

vm-up: ## start Android-in-Docker (redroid) and connect adb, see docs/REDROID.md
	scripts/redroid.sh up

vm-mirror: ## mirror + control the redroid Android with scrcpy
	scripts/redroid.sh mirror $(OPTS)

vm-down: ## stop redroid (apps and data are kept)
	scripts/redroid.sh down

vm-status: ## redroid container + adb state
	scripts/redroid.sh status

photos: ## copy new photos/videos to DEST (default ./photos); never deletes
	$(RUN) $(S)/adb-cheatsheet.sh photos $(call q,$(or $(call arg,DEST),photos))

lint: ## shellcheck the scripts (falls back to the koalaman/shellcheck Docker image)
	@if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh; \
	else echo "shellcheck not installed, using Docker"; \
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt koalaman/shellcheck:stable scripts/*.sh; fi
