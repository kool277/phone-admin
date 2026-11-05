#!/usr/bin/env bash
# Android in Docker (redroid) to mirror with scrcpy — works without KVM.
#
#   redroid.sh up            start Android, connect adb, wait until booted
#   redroid.sh mirror [ARGS] start if needed, then scrcpy on it (ARGS go to scrcpy)
#   redroid.sh down          stop the container (apps + data are kept)
#   redroid.sh status        container and adb state
#   redroid.sh logs          container log
#   redroid.sh wipe [--yes]  stop and delete the data dir (factory reset; asks first)
#
# Host needs the binder driver (root, once) — see docs/REDROID.md.
# Env: REDROID_IMAGE (redroid/redroid:14.0.0-latest)  REDROID_PORT (5600, 127.0.0.1 only)
#      REDROID_SIZE (720x1280)  REDROID_DPI (320)  REDROID_DATA (~/.local/share/redroid/<tag>)
set -euo pipefail

IMAGE=${REDROID_IMAGE:-redroid/redroid:14.0.0-latest}
# Not 5555-5585: adb probes those local ports for emulators and would list the device twice.
PORT=${REDROID_PORT:-5600}
SIZE=${REDROID_SIZE:-720x1280}
DPI=${REDROID_DPI:-320}
DATA=${REDROID_DATA:-$HOME/.local/share/redroid/${IMAGE##*:}}
NAME=redroid
SERIAL=127.0.0.1:$PORT

die() { echo "error: $*" >&2; exit 1; }
running() { [[ $(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null) == true ]]; }

cmd_up() {
  [[ -e /dev/binder ]] || grep -qw binder /proc/filesystems \
    || die "binder driver not loaded: sudo modprobe binder_linux devices=\"binder,hwbinder,vndbinder\""
  if running; then
    echo "==> $NAME already running"
  else
    docker rm "$NAME" >/dev/null 2>&1 || true   # leftover stopped container
    mkdir -p "$DATA"
    echo "==> starting $IMAGE (${SIZE} @ ${DPI}dpi, data in $DATA)"
    docker run -d --privileged --name "$NAME" \
      -v "$DATA:/data" -p "127.0.0.1:$PORT:5555" "$IMAGE" \
      androidboot.redroid_width="${SIZE%x*}" androidboot.redroid_height="${SIZE#*x}" \
      androidboot.redroid_dpi="$DPI" androidboot.redroid_gpu_mode=guest >/dev/null
  fi

  echo "==> connecting adb to $SERIAL"
  local i out
  for i in $(seq 60); do
    out=$(adb connect "$SERIAL" 2>&1) || true
    [[ $out == *"connected to"* ]] && adb -s "$SERIAL" get-state >/dev/null 2>&1 && break
    running || die "container exited — see: scripts/redroid.sh logs"
    (( i == 60 )) && die "adb could not connect to $SERIAL"
    sleep 2
  done

  echo "==> waiting for Android to finish booting"
  # shellcheck disable=SC2016  # $(...) must expand on the device, not here
  timeout 180 adb -s "$SERIAL" shell \
    'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done' \
    || die "boot did not complete in 3 min — see: scripts/redroid.sh logs"
  echo "==> ready: Android $(adb -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r') at $SERIAL"
}

cmd_mirror() {
  if ! running || ! adb -s "$SERIAL" get-state >/dev/null 2>&1; then cmd_up; fi
  # redroid has no audio output to capture.
  scrcpy -s "$SERIAL" --no-audio --window-title="redroid ${IMAGE##*:}" "$@"
}

cmd_down() {
  adb disconnect "$SERIAL" >/dev/null 2>&1 || true
  if running; then docker stop "$NAME" >/dev/null && echo "stopped"; else echo "not running"; fi
  docker rm "$NAME" >/dev/null 2>&1 || true
}

cmd_status() {
  docker ps -a --filter "name=^${NAME}\$" --format '{{.Names}}  {{.Image}}  {{.Status}}  {{.Ports}}'
  adb devices -l | grep -F "$SERIAL" || echo "adb: $SERIAL not connected"
}

cmd_logs() { docker logs "$NAME"; }

cmd_wipe() {
  [[ -d $DATA ]] || { echo "nothing to wipe: $DATA does not exist"; return 0; }
  if [[ ${1:-} != --yes ]]; then
    [[ -t 0 ]] || die "wipe deletes every app and file in the VM; run it in a terminal or add --yes"
    local r; read -r -p "Delete all apps and data of the redroid VM in $DATA? [y/N] " r
    [[ $r == [yY]* ]] || die "aborted"
  fi
  cmd_down
  # Files under /data are created by the container's root, so delete them from a container too.
  docker run --rm -v "$DATA:/d" alpine sh -c 'rm -rf /d/* /d/.[!.]* /d/..?*' \
    || die "could not delete the files in $DATA (docker access? alpine image pullable?)"
  rmdir "$DATA" || die "$DATA is not empty after the wipe"
  echo "wiped $DATA"
}

name=${1:-help}
shift || true
case "$name" in
  help|-h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
declare -F "cmd_$name" >/dev/null || die "unknown command '$name' (try: $0 help)"
command -v docker >/dev/null || die "docker not found"
command -v adb >/dev/null || die "adb not found — run scripts/install.sh"
"cmd_$name" "$@"
