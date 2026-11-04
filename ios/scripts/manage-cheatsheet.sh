#!/usr/bin/env bash
# iPhone management cheatsheet (libimobiledevice over USB). Every command is a small, commented
# function you can run directly or just read and copy.
#
#   scripts/manage-cheatsheet.sh help        # list commands
#   scripts/manage-cheatsheet.sh info        # example
#
# Several iPhones attached? Pick one with:  UDID=<udid> scripts/manage-cheatsheet.sh ...
# (`devices` shows UDIDs; it's passed as -u to libimobiledevice and as PYMOBILEDEVICE3_UDID.)
#
# Every command needs the iPhone paired once ("Trust This Computer" + passcode): see `pair`.
# Management only: nothing here, or anywhere in iOS, lets this PC tap or type on the phone.
set -euo pipefail

U=()
if [[ -n ${UDID:-} ]]; then U=(-u "$UDID"); export PYMOBILEDEVICE3_UDID=$UDID; fi

die()  { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null; }
info() { ideviceinfo "${U[@]}" "$@" 2>/dev/null; }   # info -k KEY / info -q DOMAIN -k KEY
ios_major() { local v; v=$(info -k ProductVersion) || return 1; echo "${v%%.*}"; }

# Exactly one USB iPhone, or the one named by UDID, must be attached.
need_device() {
  have idevice_id || die "libimobiledevice-utils not installed: run scripts/install.sh"
  local ids; ids=$(idevice_id -l 2>/dev/null || true)
  [[ -n $ids ]] || die "no iPhone on USB (cable connected? phone unlocked? 'systemctl status usbmuxd')"
  if [[ -n ${UDID:-} ]]; then
    grep -qx -- "$UDID" <<<"$ids" || die "UDID $UDID is not attached; attached: $(tr '\n' ' ' <<<"$ids")"
  elif (( $(wc -l <<<"$ids") > 1 )); then
    die "several iPhones attached; pick one with UDID=…: $(tr '\n' ' ' <<<"$ids")"
  fi
}

# Pairing is checked separately so the error says what to do on the phone.
need_paired() {
  need_device
  idevicepair "${U[@]}" validate >/dev/null 2>&1 \
    || die "not paired with this PC: run '$0 pair' and tap Trust on the iPhone"
}

need_pmd3() {
  have pymobiledevice3 || die "pymobiledevice3 not installed: scripts/install.sh --no-mirror --no-manage --pymobiledevice3"
}

confirm() { local r; read -r -p "$1 [y/N] " r; [[ $r == [yY]* ]] || die "aborted"; }

## devices                 — UDIDs and names of iPhones attached over USB
cmd_devices() {
  local id
  for id in $(idevice_id -l); do printf '%s  %s\n' "$id" "$(idevice_id "$id" 2>/dev/null || echo '(not paired)')"; done
}

## pair                    — pair with this PC: unlock the phone, tap "Trust", enter the passcode
cmd_pair() {
  need_device
  if idevicepair "${U[@]}" validate >/dev/null 2>&1; then echo "already paired"; return; fi
  # The first call makes the iPhone show "Trust This Computer?"; it fails until you accept.
  idevicepair "${U[@]}" pair >/dev/null 2>&1 || true
  echo "On the iPhone: unlock it, tap Trust, enter the passcode. Waiting up to 2 minutes…"
  local i
  for ((i = 0; i < 60; i++)); do
    if idevicepair "${U[@]}" pair >/dev/null 2>&1; then echo "paired"; return; fi
    sleep 2
  done
  die "not paired. If you tapped Don't Trust, unplug and replug to get the prompt again"
}

## unpair                  — forget this PC on the iPhone (the next use asks Trust again)
cmd_unpair() { need_device; idevicepair "${U[@]}" unpair; }

## info                    — name, model, iOS version, battery, storage, Developer Mode
cmd_info() {
  need_paired
  local total free
  printf 'name:      %s\n' "$(info -k DeviceName)"
  printf 'model:     %s (%s)\n' "$(info -k ProductType)" "$(info -k ModelNumber)"
  printf 'iOS:       %s (%s)\n' "$(info -k ProductVersion)" "$(info -k BuildVersion)"
  printf 'udid:      %s\n' "$(info -k UniqueDeviceID)"
  printf 'battery:   %s%%\n' "$(info -q com.apple.mobile.battery -k BatteryCurrentCapacity)"
  total=$(info -q com.apple.disk_usage -k TotalDataCapacity || true)
  free=$(info -q com.apple.disk_usage -k TotalDataAvailable || true)
  if [[ $total =~ ^[0-9]+$ && $free =~ ^[0-9]+$ ]]; then
    printf 'storage:   %s GB free of %s GB\n' "$((free / 1000000000))" "$((total / 1000000000))"
  fi
  # Key exists from iOS 16 on; empty on older versions.
  printf 'dev mode:  %s\n' "$(info -q com.apple.security.mac.amfi -k DeveloperModeStatus || echo n/a)"
}

## info-all [DOMAIN]       — every lockdown value (ideviceinfo), optionally one domain
cmd_info-all() { need_paired; if [[ -n ${1:-} ]]; then ideviceinfo "${U[@]}" -q "$1"; else ideviceinfo "${U[@]}"; fi; }

## apps [FILTER]           — user-installed apps: bundle id, version, name
cmd_apps() {
  need_paired
  # -o list_system / list_all for the others. Output is CSV: CFBundleIdentifier, CFBundleVersion, CFBundleDisplayName
  ideviceinstaller "${U[@]}" -l -o list_user | grep -i -- "${1:-.}" || true
}

## install IPA             — install/upgrade an .ipa signed for this device (no sideloading bypass)
cmd_install() {
  local ipa=${1:?usage: install IPA}
  [[ -f $ipa ]] || die "no such file: $ipa"
  need_paired
  # iOS installs only apps signed for it: App Store/TestFlight builds, or your own development or
  # ad-hoc builds that include this UDID. Anything else fails with a signature/provisioning error.
  ideviceinstaller "${U[@]}" -i "$ipa"
}

## uninstall BUNDLEID      — remove an app and its data
cmd_uninstall() { local id=${1:?usage: uninstall BUNDLEID}; need_paired; ideviceinstaller "${U[@]}" -U "$id"; }

## backup [DIR]            — incremental backup into DIR (default ./backups); FULL=1 forces a full one
cmd_backup() {
  local dir=${1:-backups}
  need_paired
  mkdir -p "$dir"
  # Creates DIR/<UDID>/. Same format as Finder/iTunes. If backup encryption is on, the phone may ask
  # for its passcode before starting.
  if [[ ${FULL:-0} == 1 ]]; then idevicebackup2 "${U[@]}" backup --full "$dir"; else idevicebackup2 "${U[@]}" backup "$dir"; fi
}

## backup-info [DIR]       — details of the last backup in DIR
cmd_backup-info() { need_paired; idevicebackup2 "${U[@]}" info "${1:-backups}"; }

## backup-encryption on|off — set backup encryption; prompts for the password (not on the command line)
cmd_backup-encryption() {
  local mode=${1:?usage: backup-encryption on|off}
  [[ $mode == on || $mode == off ]] || die "usage: backup-encryption on|off"
  need_paired
  # Encrypted backups also contain saved passwords, Wi-Fi, Health and call history. The password is
  # stored on the iPhone; losing it makes the backups unreadable. iOS asks for the passcode on the phone.
  idevicebackup2 "${U[@]}" -i encryption "$mode"
}

## restore [DIR]           — restore the last backup in DIR onto the phone (overwrites it; asks first)
cmd_restore() {
  local dir=${1:-backups}
  need_paired
  echo "This replaces the iPhone's data with the backup in $dir and reboots it."
  echo "Find My iPhone must be off (Settings → [your name] → Find My) or iOS refuses."
  confirm "Restore now?"
  idevicebackup2 "${U[@]}" -i restore --system --settings "$dir"
}

## screenshot [FILE]       — PNG via pymobiledevice3, or TIFF via idevicescreenshot (needs Developer Mode)
cmd_screenshot() {
  need_paired
  local stamp; stamp=$(date +%Y%m%d-%H%M%S)
  local major; major=$(ios_major || echo 0)
  if have pymobiledevice3; then
    local f=${1:-screenshot-$stamp.png}
    # iOS 17.4+: opens its own no-root tunnel. iOS 17.0–17.3: needs `sudo pymobiledevice3 remote tunneld`
    # running and PYMOBILEDEVICE3_TUNNEL=<udid>. All versions: Developer Mode on and the DDI mounted.
    pymobiledevice3 developer dvt screenshot "$f" \
      || die "screenshot failed: check '$0 dev-mode', then '$0 mount-ddi' (docs/MANAGE.md#screenshots)"
    echo "$f"
  elif (( major >= 17 )); then
    die "iOS $major: Ubuntu's libimobiledevice can't take screenshots; install pymobiledevice3 (docs/MANAGE.md#screenshots)"
  else
    local f=${1:-screenshot-$stamp.tiff}
    # Needs the Developer Disk Image for this iOS version mounted first (ideviceimagemounter or mount-ddi).
    idevicescreenshot "${U[@]}" "$f" || die "screenshot failed: mount the Developer Disk Image first (docs/MANAGE.md#screenshots)"
  fi
}

## dev-mode                — iOS 16+: show the Developer Mode switch; you turn it on by hand on the phone
cmd_dev-mode() {
  need_paired; need_pmd3
  local s; s=$(info -q com.apple.security.mac.amfi -k DeveloperModeStatus || true)
  [[ $s == true ]] && { echo "Developer Mode is already on"; return; }
  # Only makes the switch visible. Turning it on is done on the phone and needs a restart + passcode.
  pymobiledevice3 amfi reveal-developer-mode
  echo "iPhone: Settings → Privacy & Security → Developer Mode → On → Restart → confirm with the passcode."
}

## mount-ddi               — mount the Developer Disk Image (downloads the right one; iOS 17+ personalized)
cmd_mount-ddi() { need_paired; need_pmd3; pymobiledevice3 mounter auto-mount; }

## mount [DIR]             — mount the camera roll/media area (DCIM, …) at DIR (default ./iphone-media)
cmd_mount() {
  local dir=${1:-iphone-media}
  need_paired
  mkdir -p "$dir"
  ifuse "$dir" "${U[@]}" && echo "mounted at $dir  (unmount: $0 umount $dir)"
}

## shared-apps             — apps whose Documents folder can be mounted (File Sharing enabled)
cmd_shared-apps() { need_paired; ifuse "${U[@]}" --list-apps; }

## mount-docs BUNDLEID [DIR] — mount an app's Documents folder (only apps listed by shared-apps)
cmd_mount-docs() {
  local id=${1:?usage: mount-docs BUNDLEID [DIR]} dir=${2:-${1}-docs}
  need_paired
  mkdir -p "$dir"
  ifuse "$dir" "${U[@]}" --documents "$id" && echo "mounted at $dir  (unmount: $0 umount $dir)"
}

## umount DIR              — unmount something mounted by mount / mount-docs
cmd_umount() { fusermount -u "${1:?usage: umount DIR}"; }

## syslog [STRING]         — live device log, quiet mode, optionally only lines containing STRING
cmd_syslog() {
  need_paired
  if [[ -n ${1:-} ]]; then idevicesyslog "${U[@]}" -q -m "$1"; else idevicesyslog "${U[@]}" -q; fi
}

## crashlogs [DIR]         — copy crash reports to DIR (default ./crashlogs), keep them on the phone
cmd_crashlogs() { local d=${1:-crashlogs}; need_paired; mkdir -p "$d"; idevicecrashreport "${U[@]}" -k -e "$d"; }

## name [NEW]              — show or set the iPhone's name
cmd_name() { need_paired; idevicename "${U[@]}" "$@"; }

## restart / shutdown      — restart or power off the phone
cmd_restart()  { need_paired; idevicediagnostics "${U[@]}" restart; }
cmd_shutdown() { need_paired; confirm "Power off the iPhone?"; idevicediagnostics "${U[@]}" shutdown; }

## doctor                  — check tools, services, the attached iPhone and what its iOS version allows
cmd_doctor() {
  local t ok=1
  for t in uxplay idevice_id ideviceinfo idevicepair ideviceinstaller idevicebackup2 ifuse; do
    if have "$t"; then echo "ok    $t"; else echo "MISS  $t   (scripts/install.sh)"; ok=0; fi
  done
  if have pymobiledevice3; then echo "ok    pymobiledevice3 $(pymobiledevice3 version 2>/dev/null || true)"
  else echo "--    pymobiledevice3 (optional; needed for screenshots on iOS 17+)"; fi
  if systemctl is-active --quiet avahi-daemon; then echo "ok    avahi-daemon running (mirroring discovery)"
  else echo "MISS  avahi-daemon not running: sudo systemctl enable --now avahi-daemon"; ok=0; fi
  # usbmuxd is started by udev when an Apple device is plugged in, so "inactive" without a phone is normal.
  echo "info  usbmuxd: $(systemctl is-active usbmuxd 2>/dev/null || true)"

  local ids; ids=$(idevice_id -l 2>/dev/null || true)
  if [[ -z $ids ]]; then echo "--    no iPhone on USB"; (( ok )); return; fi
  echo "ok    iPhone(s) on USB: $(tr '\n' ' ' <<<"$ids")"
  if [[ -z ${UDID:-} ]] && (( $(wc -l <<<"$ids") > 1 )); then echo "--    several attached; set UDID=… for the rest"; return; fi
  if ! idevicepair "${U[@]}" validate >/dev/null 2>&1; then echo "MISS  not paired: $0 pair"; return 1; fi
  echo "ok    paired"
  local v major dm
  v=$(info -k ProductVersion); major=${v%%.*}
  dm=$(info -q com.apple.security.mac.amfi -k DeveloperModeStatus || true)
  echo "info  iOS $v, Developer Mode: ${dm:-n/a}"
  (( major >= 16 )) && [[ $dm != true ]] && echo "note  screenshots need Developer Mode: $0 dev-mode"
  (( major >= 17 )) && ! have pymobiledevice3 && echo "note  iOS 17+: screenshots need pymobiledevice3"
  [[ $v =~ ^17\.[0-3](\.|$) ]] && echo "note  iOS 17.0–17.3: screenshots also need 'sudo pymobiledevice3 remote tunneld' + PYMOBILEDEVICE3_TUNNEL=<udid>"
  (( ok ))
}

## help                    — this list
cmd_help() {
  sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0"
  echo; echo "Commands:"
  grep -E '^## ' "$0" | sed 's/^## /  /'
}

cmd=${1:-help}; shift || true
declare -F "cmd_$cmd" >/dev/null || die "unknown command: $cmd (try: $0 help)"
"cmd_$cmd" "$@"
