# android-admin — run `make help`.
#
# Target one device among several:  make mirror SERIAL=192.168.1.42:5555
# Extra scrcpy flags:               make mirror OPTS="--max-size=1600 --turn-screen-off"

SHELL := /bin/bash
OPTS  ?=

# adb and scrcpy both honor ANDROID_SERIAL.
ifdef SERIAL
export ANDROID_SERIAL := $(SERIAL)
endif

.PHONY: help install install-apt devices info mirror mirror-usb mirror-wifi mirror-tcpip \
        desktop record pair connect wireless disconnect install-apk rustdesk-android \
        rustdesk-perms vm-up vm-mirror vm-down vm-status lint

help: ## show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-17s %s\n", $$1, $$2}'

install: ## install scrcpy + adb (official release, bundles current adb)
	scripts/install.sh

install-apt: ## install Ubuntu-packaged scrcpy/adb instead (older)
	scripts/install.sh --apt

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
	scrcpy --tcpip$(if $(IP),=$(IP)) $(OPTS)

desktop: ## separate virtual display on the phone (Android 10+), SIZE=1920x1080
	scrcpy --new-display=$(or $(SIZE),1920x1080) $(OPTS)

record: ## record screen to FILE without opening a window (Ctrl+C to stop)
	scrcpy --no-playback --record=$(or $(FILE),record-$$(date +%Y%m%d-%H%M%S).mp4) $(OPTS)

pair: ## Android 11+ wireless pairing: ADDR=ip:pairport [CODE=123456]
	scripts/wireless.sh pair $(ADDR) $(CODE)

connect: ## Android 11+ wireless connect: ADDR=ip:port
	scripts/wireless.sh connect $(ADDR)

wireless: ## any Android: phone on USB → adb over Wi-Fi on PORT (default 5555)
	scripts/wireless.sh tcpip $(PORT)

disconnect: ## drop TCP/IP adb connections (ADDR=ip:port for just one)
	scripts/wireless.sh disconnect $(ADDR)

install-apk: ## install APK=path/to/app.apk (keeps app data)
	@test -n "$(APK)" || { echo "usage: make install-apk APK=path/to/app.apk"; exit 2; }
	scripts/adb-cheatsheet.sh install $(APK)

rustdesk-android: ## download + install latest RustDesk APK matching the phone's CPU
	scripts/adb-cheatsheet.sh rustdesk-apk

rustdesk-perms: ## optional: battery exemption + input (accessibility) via adb
	scripts/adb-cheatsheet.sh rustdesk-perms

vm-up: ## start Android-in-Docker (redroid) and connect adb, see docs/REDROID.md
	scripts/redroid.sh up

vm-mirror: ## mirror + control the redroid Android with scrcpy
	scripts/redroid.sh mirror $(OPTS)

vm-down: ## stop redroid (apps and data are kept)
	scripts/redroid.sh down

vm-status: ## redroid container + adb state
	scripts/redroid.sh status

lint: ## shellcheck the scripts
	shellcheck scripts/*.sh
