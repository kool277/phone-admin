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
# Quote one word for the phone's shell: `adb shell` joins its arguments into a single command line.
sq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

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
  local pkg=${1:?usage: apk PKG} paths p
  paths=$(sh_ pm path "$pkg" || true)
  [[ -n $paths ]] || die "$pkg is not installed (see: $0 packages)"
  mkdir -p "$pkg"
  while read -r p; do adb pull "${p#package:}" "$pkg/" </dev/null; done <<<"$paths"
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

## type TEXT               — type text into the focused field (printable ASCII only)
cmd_type() {
  local text=${1:?usage: type TEXT} c piece='' i cmds=() LC_ALL=C
  [[ $text =~ ^[\ -~]+$ ]] || die "type: printable ASCII only (input text can't type other characters)"
  # `input text` turns %s into a space and has no escape for it, so: spaces are sent as the SPACE
  # key, every piece ends right after a '%', and each piece is quoted for the phone's shell.
  flush() { [[ -z $piece ]] || cmds+=("input text $(sq "$piece")"); piece=''; }
  for ((i = 0; i < ${#text}; i++)); do
    c=${text:i:1}
    case $c in
      ' ') flush; cmds+=("input keyevent 62") ;;
      %)   piece+=%; flush ;;
      *)   piece+=$c ;;
    esac
  done
  flush
  local IFS=';'; sh_ "${cmds[*]}"
}

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
  trap 'rm -rf "$tmp"' EXIT
  echo "==> $url"
  curl -fL --progress-bar -o "$tmp/rustdesk.apk" "$url"
  adb install -r "$tmp/rustdesk.apk"
  echo "Next: docs/RUSTDESK-ANDROID.md (server config + permissions, on the phone)"
}

## rustdesk-perms          — optional: exempt RustDesk from battery optimization, and report whether
##                           its Input Control is on. Input itself is switched on by hand on the phone.
cmd_rustdesk-perms() {
  local svc="$RUSTDESK_PKG/$RUSTDESK_PKG.InputService" cur
  [[ -n $(sh_ pm path "$RUSTDESK_PKG" || true) ]] || die "RustDesk ($RUSTDESK_PKG) is not installed"
  sh_ dumpsys deviceidle whitelist "+$RUSTDESK_PKG"
  # Read-only: accessibility gives an app control of the phone, so the owner grants it on the
  # phone itself (Android's own consent screen). Never write enabled_accessibility_services here.
  cur=$(sh_ settings get secure enabled_accessibility_services || true)
  if [[ $cur == *"$svc"* ]]; then
    echo "Input Control: on"
  else
    echo "Input Control: off. On the phone: RustDesk → Share screen → Input Control → RustDesk Input → On"
    echo "(Android 13+ 'Restricted setting'? Settings → Apps → RustDesk → ⋮ → Allow restricted settings)"
  fi
}

## photos [DEST] [DIR...]  — copy NEW photos/videos to DEST (default ./photos); never deletes or overwrites
cmd_photos() {
  local dest=${1:-photos}; shift || true
  local dirs=("$@") list=() f rel target copied=0 had=0 failed=0 d qdirs=''
  (( ${#dirs[@]} )) || dirs=(/sdcard/DCIM /sdcard/Pictures /sdcard/Movies)
  for d in "${dirs[@]}"; do qdirs+=" $(sq "$d")"; done
  # Skip hidden entries: .thumbnails/, and Android 11+ trash and in-progress files
  # (.trashed-<time>-IMG_….jpg, .pending-…), which would otherwise come back as "new" photos.
  mapfile -t list < <(sh_ "find$qdirs -type f ! -path '*/.*' 2>/dev/null" || true)
  (( ${#list[@]} )) || die "no files under: ${dirs[*]}"
  mkdir -p "$dest"
  for f in "${list[@]}"; do
    rel=${f#/sdcard/}; rel=${rel#/storage/emulated/0/}
    target="$dest/$rel"
    if [[ -e $target ]]; then had=$((had + 1)); continue; fi
    mkdir -p "$(dirname "$target")"
    # -a keeps the capture time as the file's mtime, so photo apps sort correctly.
    # Pull to .part first: an interrupted run never leaves a truncated file that looks complete.
    # </dev/null: adb must not eat the loop's stdin.
    if adb pull -a "$f" "$target.part" </dev/null >/dev/null && mv "$target.part" "$target"; then
      echo "$rel"; copied=$((copied + 1))
    else
      rm -f "$target.part"; echo "FAILED  $rel" >&2; failed=$((failed + 1))
    fi
  done
  echo "copied $copied new, $had already in $dest"
  if (( failed )); then
    die "$failed file(s) FAILED (phone unplugged or locked? disk full?); re-run to retry only those"
  fi
}

## doctor                  — check adb/scrcpy, the Ubuntu adb package conflict, devices and authorization
cmd_doctor() {
  local ok=1 serial state
  if command -v adb >/dev/null; then echo "ok    $(adb version | head -1) ($(command -v adb))"
  else echo "MISS  adb   (scripts/install.sh)"; ok=0; fi
  if command -v scrcpy >/dev/null; then echo "ok    $(scrcpy --version 2>/dev/null | head -1)"
  else echo "MISS  scrcpy   (scripts/install.sh)"; ok=0; fi
  # Two adb versions fight over the server port and keep killing each other's server.
  if dpkg -s adb >/dev/null 2>&1 && [[ $(command -v adb) != /usr/bin/adb ]]; then
    echo "warn  Ubuntu's 'adb' package is installed too; remove it: sudo apt remove adb"
  fi
  [[ -e /etc/udev/rules.d/51-android.rules || -e /usr/lib/udev/rules.d/51-android.rules \
     || -e /lib/udev/rules.d/51-android.rules ]] \
    && echo "ok    udev rules for USB access" || echo "--    no 51-android udev rules (only matters if USB devices show as 'no permissions')"
  command -v adb >/dev/null || { (( ok )); return; }
  local n=0
  while read -r serial state; do
    [[ -n $serial ]] || continue
    n=$((n + 1))
    case $state in
      device)       echo "ok    $serial: $(adb -s "$serial" shell getprop ro.product.model </dev/null | tr -d '\r'), Android $(adb -s "$serial" shell getprop ro.build.version.release </dev/null | tr -d '\r')" ;;
      unauthorized) echo "MISS  $serial: unauthorized: unlock the phone and accept the USB debugging (RSA) prompt"; ok=0 ;;
      offline)      echo "MISS  $serial: offline: replug the cable, or 'adb kill-server' and retry"; ok=0 ;;
      *)            echo "MISS  $serial: $state"; ok=0 ;;
    esac
  done < <(adb devices | tail -n +2)
  (( n )) || echo "--    no devices: USB debugging on and cable in, or 'make pair'/'make connect' for Wi-Fi"
  (( n > 1 )) && echo "note  several devices: pick one with SERIAL=… (make) or ANDROID_SERIAL=… (scripts)"
  (( ok ))
}

cmd_help() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  echo "Commands:"
  grep -E '^## ' "$0" | sed 's/^## /  /'
}

name=${1:-help}
shift || true
declare -F "cmd_$name" >/dev/null || die "unknown command '$name' (try: $0 help)"
if [[ $name != help && $name != doctor ]]; then
  command -v adb >/dev/null || die "adb not found — run scripts/install.sh"
  [[ $name == devices ]] || adb get-state >/dev/null 2>&1 \
    || die "no single authorized device (see 'adb devices'; several? set ANDROID_SERIAL)"
fi
"cmd_$name" "$@"
