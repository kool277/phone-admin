#!/usr/bin/env bash
# Install scrcpy + adb on Ubuntu.
#
# Default: the official static scrcpy release from GitHub (x86_64). It bundles a
# current adb, which we expose as `adb` so scrcpy and your shell share one adb
# server version.
#
#   scripts/install.sh            # official release (recommended)
#   scripts/install.sh --apt      # Ubuntu packages instead (much older; 24.04 ships scrcpy 1.25)
#   scripts/install.sh --no-deps  # skip apt (udev rules) — used for testing
#
# Env overrides: SCRCPY_VERSION=v5.0.1  PREFIX=/opt/scrcpy  BINDIR=/usr/local/bin
#
# Audio: scrcpy >= 2.0 forwards audio itself on Android 11+, so sndcpy is not
# needed (and is unmaintained). See docs/SCRCPY.md.
set -euo pipefail

PREFIX=${PREFIX:-/opt/scrcpy}
BINDIR=${BINDIR:-/usr/local/bin}
REPO=Genymobile/scrcpy
MODE=release
DEPS=1

for arg in "$@"; do
  case "$arg" in
    --apt) MODE=apt ;;
    --no-deps) DEPS=0 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Run "${@:2}" with sudo only if path $1 (or its nearest existing ancestor) isn't writable.
as_root_for() {
  local p=$1
  while [[ ! -e $p ]]; do p=$(dirname "$p"); done
  if [[ -w $p ]]; then "${@:2}"; else sudo "${@:2}"; fi
}

if (( DEPS )); then
  echo "==> apt: udev rules for Android devices + download tools"
  sudo apt-get update -qq
  # android-sdk-platform-tools-common ships /lib/udev/rules.d/51-android.rules
  sudo apt-get install -y android-sdk-platform-tools-common curl ca-certificates tar
  if ! id -nG "$USER" | grep -qw plugdev; then
    sudo usermod -aG plugdev "$USER"
    echo "    added $USER to 'plugdev' — log out and back in for USB access"
  fi
fi

if [[ $MODE == apt ]]; then
  sudo apt-get install -y scrcpy adb
  scrcpy --version | head -1
  adb version | head -1
  exit 0
fi

if [[ $(uname -m) != x86_64 ]]; then
  echo "Official Linux build is x86_64 only. Use --apt, or build from source:" >&2
  echo "  https://github.com/Genymobile/scrcpy/blob/master/doc/linux.md" >&2
  exit 1
fi

if [[ -z ${SCRCPY_VERSION:-} ]]; then
  latest=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
  SCRCPY_VERSION=$(grep -m1 '"tag_name"' <<<"$latest" | cut -d'"' -f4)
fi
[[ -n $SCRCPY_VERSION ]] || { echo "could not resolve latest scrcpy version" >&2; exit 1; }

tarball="scrcpy-linux-x86_64-$SCRCPY_VERSION.tar.gz"
base="https://github.com/$REPO/releases/download/$SCRCPY_VERSION"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading scrcpy $SCRCPY_VERSION"
curl -fL --progress-bar -o "$tmp/$tarball" "$base/$tarball"
curl -fsSL -o "$tmp/SHA256SUMS.txt" "$base/SHA256SUMS.txt"
(cd "$tmp" && sha256sum --check --ignore-missing --strict SHA256SUMS.txt)

tar -xzf "$tmp/$tarball" -C "$tmp"
as_root_for "$PREFIX" rm -rf "$PREFIX"
as_root_for "$PREFIX" mkdir -p "$PREFIX"
as_root_for "$PREFIX" cp -a "$tmp/${tarball%.tar.gz}/." "$PREFIX/"

# Wrapper (not a symlink) so scrcpy always finds scrcpy-server and its bundled adb.
as_root_for "$BINDIR" mkdir -p "$BINDIR"
printf '#!/bin/sh\nexec %s/scrcpy "$@"\n' "$PREFIX" > "$tmp/scrcpy-wrapper"
as_root_for "$BINDIR/scrcpy" install -m 0755 "$tmp/scrcpy-wrapper" "$BINDIR/scrcpy"
as_root_for "$BINDIR/adb" ln -sf "$PREFIX/adb" "$BINDIR/adb"

if dpkg -s adb >/dev/null 2>&1; then
  echo "!!  Ubuntu's 'adb' package is also installed. Two adb versions fight over the"
  echo "    adb server ('server version doesn't match this client'). Remove it:"
  echo "      sudo apt remove adb"
fi

echo "==> installed"
"$BINDIR/scrcpy" --version | head -1
"$BINDIR/adb" version | head -1
echo "Optional, for hardware video decoding (scrcpy >= 5.0): sudo apt install va-driver-all"
