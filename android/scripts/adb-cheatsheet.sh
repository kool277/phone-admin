#!/usr/bin/env bash
# adb management cheatsheet — every command is a small, commented function you
# can run directly or just read and copy.
#
#   scripts/adb-cheatsheet.sh help          # list commands
#   scripts/adb-cheatsheet.sh packages ram  # example
#
# Several devices attached? Pick one with:  ANDROID_SERIAL=<serial> scripts/adb-cheatsheet.sh ...
# (adb and scrcpy both honor ANDROID_SERIAL; `adb devices` shows serials.)
set -euo pipefail

RUSTDESK_PKG=com.carriez.flutter_hbb

die() { echo "error: $*" >&2; exit 1; }
sh_() { adb shell "$@" | tr -d '\r'; }

## devices                 — attached devices with model/transport
cmd_devices() { adb devices -l; }

## info                    — model, Android version/API level, CPU ABI, battery, storage
cmd_info() {
  printf 'model:   %s %s\n' "$(sh_ getprop ro.product.manufacturer)" "$(sh_ getprop ro.product.model)"
  printf 'android: %s (API %s)\n' "$(sh_ getprop ro.build.version.release)" "$(sh_ getprop ro.build.version.sdk)"
  printf 'abi:     %s\n' "$(sh_ getprop ro.product.cpu.abi)"
  printf 'battery: %s%%\n' "$(sh_ dumpsys battery | awk -F': ' '/ level:/ {print $2}')"
  sh_ df -h /data | tail -1 | awk '{print "storage: " $3 " used / " $2 " (" $5 ")"}'
}

## packages [FILTER]       — user-installed packages (pm list packages -3), optional grep
cmd_packages() {
  # -3 third-party, -s system, -d disabled, -e enabled, -f with APK path
  sh_ pm list packages -3 | sed 's/^package://' | sort | grep -i -- "${1:-.}" || true
}

## packages-system [FILTER] — system packages
cmd_packages-system() { sh_ pm list packages -s | sed 's/^package://' | sort | grep -i -- "${1:-.}" || true; }

## install APK [APK...]    — install/update (keeps data); several files = one split-APK app
cmd_install() {
  (( $# )) || die "usage: install APK [APK...]"
  # -r replace existing, -d also allow version downgrade (debuggable apps only), -g grant all runtime perms
  if (( $# == 1 )); then adb install -r "$1"; else adb install-multiple -r "$@"; fi
}

## uninstall PKG           — remove an app completely
cmd_uninstall() { adb uninstall "${1:?usage: uninstall PKG}"; }

## debloat PKG             — remove a preinstalled app for user 0 (reversible: restore PKG)
cmd_debloat() { sh_ pm uninstall -k --user 0 "${1:?usage: debloat PKG}"; }

## restore PKG             — bring back an app removed with debloat
cmd_restore() { sh_ cmd package install-existing "${1:?usage: restore PKG}"; }

## disable PKG / enable PKG — freeze/unfreeze an app without removing it
cmd_disable() { sh_ pm disable-user --user 0 "${1:?usage: disable PKG}"; }
cmd_enable()  { sh_ pm enable "${1:?usage: enable PKG}"; }

## apk PKG                 — pull an installed app's APK(s) into ./PKG/
cmd_apk() {
  local pkg=${1:?usage: apk PKG}
  mkdir -p "$pkg"
  sh_ pm path "$pkg" | sed 's/^package://' | while read -r p; do adb pull "$p" "$pkg/"; done
}

## push SRC [DEST]         — copy to phone (default /sdcard/Download/)
cmd_push() { adb push "${1:?usage: push SRC [DEST]}" "${2:-/sdcard/Download/}"; }

## pull SRC [DEST]         — copy from phone, e.g. pull /sdcard/DCIM/Camera ./photos
cmd_pull() { adb pull "${1:?usage: pull SRC [DEST]}" "${2:-.}"; }

## screenshot [FILE]       — PNG screenshot straight to the PC
cmd_screenshot() {
  local f=${1:-screenshot-$(date +%Y%m%d-%H%M%S).png}
  adb exec-out screencap -p > "$f" && echo "$f"
}

## logcat [PKG]            — live log, optionally only one app's process
cmd_logcat() {
  if [[ -n ${1:-} ]]; then
    local pid; pid=$(sh_ pidof -s "$1") || true
    [[ -n $pid ]] || die "$1 is not running"
    adb logcat -v color --pid="$pid"
  else
    adb logcat -v color
  fi
}

## crashes                 — dump the crash buffer (recent app crashes) and exit
cmd_crashes() { adb logcat -b crash -d; }

## bugreport [DIR]         — full bugreport zip (slow, large)
cmd_bugreport() { adb bugreport "${1:-.}"; }

## wake                    — turn the screen on
cmd_wake() { sh_ input keyevent KEYCODE_WAKEUP; }

## type TEXT               — type text into the focused field (ASCII only)
cmd_type() { sh_ input text "$(printf '%s' "${1:?usage: type TEXT}" | sed 's/ /%s/g')"; }

## stay-awake on|off       — keep screen on while charging (USB/AC/wireless)
cmd_stay-awake() {
  case "${1:-}" in on) v=7 ;; off) v=0 ;; *) die "usage: stay-awake on|off" ;; esac
  sh_ settings put global stay_on_while_plugged_in "$v"
}

## reboot [recovery|bootloader] — reboot (optionally into recovery/bootloader)
cmd_reboot() { adb reboot ${1:+"$1"}; }

## rustdesk-apk            — download latest RustDesk APK for this phone's CPU and install it
cmd_rustdesk-apk() {
  local abi arch url tmp
  abi=$(sh_ getprop ro.product.cpu.abi)
  case "$abi" in
    arm64-v8a) arch=aarch64 ;; armeabi-v7a) arch=armv7 ;; x86_64) arch=x86_64 ;;
    *) arch=universal ;;
  esac
  url=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest)
  url=$(grep -o "https://[^\"]*/rustdesk-[0-9.]*-$arch\(-signed\)\?\.apk" <<<"$url" | head -1) || true
  [[ -n $url ]] || die "no RustDesk APK found for $abi"
  tmp=$(mktemp -d)
  echo "==> $url"
  curl -fL --progress-bar -o "$tmp/rustdesk.apk" "$url"
  adb install -r "$tmp/rustdesk.apk" || { rm -rf "$tmp"; exit 1; }
  rm -rf "$tmp"
  echo "Next: docs/RUSTDESK-ANDROID.md (server config + permissions, on the phone)"
}

## rustdesk-perms          — optional adb shortcut: exempt RustDesk from battery optimization
##                           and enable its accessibility (input) service. See docs/RUSTDESK-ANDROID.md.
cmd_rustdesk-perms() {
  local svc="$RUSTDESK_PKG/$RUSTDESK_PKG.InputService" cur
  sh_ pm path "$RUSTDESK_PKG" >/dev/null || die "RustDesk ($RUSTDESK_PKG) is not installed"
  sh_ dumpsys deviceidle whitelist "+$RUSTDESK_PKG"
  # Append to (don't replace) any accessibility services already enabled.
  cur=$(sh_ settings get secure enabled_accessibility_services)
  if [[ $cur == *"$svc"* ]]; then
    echo "accessibility service already enabled"
  else
    [[ -z $cur || $cur == null ]] && cur=$svc || cur="$cur:$svc"
    sh_ settings put secure enabled_accessibility_services "$cur"
    sh_ settings put secure accessibility_enabled 1
    echo "enabled $svc"
  fi
}

cmd_help() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  echo "Commands:"
  grep -E '^## ' "$0" | sed 's/^## /  /'
}

name=${1:-help}
shift || true
declare -F "cmd_$name" >/dev/null || die "unknown command '$name' (try: $0 help)"
if [[ $name != help ]]; then
  command -v adb >/dev/null || die "adb not found — run scripts/install.sh"
  [[ $name == devices ]] || adb get-state >/dev/null 2>&1 \
    || die "no single authorized device (see 'adb devices'; several? set ANDROID_SERIAL)"
fi
"cmd_$name" "$@"
