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
# Env overrides: SCRCPY_VERSION=v5.0.1  SCRCPY_PREFIX=/opt/scrcpy  SCRCPY_BINDIR=/usr/local/bin
# SCRCPY_PREFIX is scrcpy's own folder and is replaced on every install, so it must be new,
# empty, or a previous scrcpy install. (Not plain PREFIX: that is often set for other builds.)
#
# Audio: scrcpy >= 2.0 forwards audio itself on Android 11+, so sndcpy is not
# needed (and is unmaintained). See docs/SCRCPY.md.
set -euo pipefail

PREFIX=${SCRCPY_PREFIX:-/opt/scrcpy}
BINDIR=${SCRCPY_BINDIR:-/usr/local/bin}
REPO=Genymobile/scrcpy
MODE=release
DEPS=1

for arg in "$@"; do
  case "$arg" in
    --apt) MODE=apt ;;
    --no-deps) DEPS=0 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

# Run "${@:2}" with sudo only if directory $1 (or its nearest existing ancestor) isn't writable.
# Always pass the directory being changed, never a file in it: -w on a symlink tests its target.
as_root_in() {
  local d=$1
  while [[ ! -e $d ]]; do d=$(dirname "$d"); done
  if [[ -d $d && -w $d && -x $d ]]; then "${@:2}"; else sudo "${@:2}"; fi
}

# PREFIX gets `rm -rf` below, so only ever replace an empty folder or an earlier scrcpy install.
[[ $PREFIX == /?* && $PREFIX != *"'"* ]] || die "SCRCPY_PREFIX must be an absolute path without quotes: $PREFIX"
PREFIX=${PREFIX%/}
if [[ -e $PREFIX && ! -e $PREFIX/scrcpy-server ]]; then
  [[ -d $PREFIX && -r $PREFIX && -x $PREFIX && -z $(ls -A "$PREFIX") ]] \
    || die "$PREFIX exists and is not a scrcpy install; refusing to replace it. Set SCRCPY_PREFIX to a new or empty folder."
fi

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
  latest=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest") \
    || die "could not reach the GitHub API; set SCRCPY_VERSION=vX.Y.Z to skip the lookup"
  SCRCPY_VERSION=$(grep -m1 '"tag_name"' <<<"$latest" | cut -d'"' -f4 || true)
fi
[[ -n $SCRCPY_VERSION ]] || die "could not resolve the latest scrcpy version; set SCRCPY_VERSION=vX.Y.Z"

tarball="scrcpy-linux-x86_64-$SCRCPY_VERSION.tar.gz"
base="https://github.com/$REPO/releases/download/$SCRCPY_VERSION"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading scrcpy $SCRCPY_VERSION"
curl -fL --progress-bar -o "$tmp/$tarball" "$base/$tarball"
curl -fsSL -o "$tmp/SHA256SUMS.txt" "$base/SHA256SUMS.txt"
(cd "$tmp" && sha256sum --check --ignore-missing --strict SHA256SUMS.txt)

tar -xzf "$tmp/$tarball" -C "$tmp"
parent=$(dirname "$PREFIX")
as_root_in "$parent" rm -rf "$PREFIX"
as_root_in "$parent" mkdir -p "$PREFIX"
as_root_in "$PREFIX" cp -R --no-preserve=ownership "$tmp/${tarball%.tar.gz}/." "$PREFIX/"

# Wrapper (not a symlink) so scrcpy always finds scrcpy-server and its bundled adb.
# Single quotes keep a PREFIX with spaces intact (quotes in PREFIX are rejected above).
as_root_in "$BINDIR" mkdir -p "$BINDIR"
printf '#!/bin/sh\nexec '\''%s/scrcpy'\'' "$@"\n' "$PREFIX" > "$tmp/scrcpy-wrapper"
as_root_in "$BINDIR" install -m 0755 "$tmp/scrcpy-wrapper" "$BINDIR/scrcpy"
as_root_in "$BINDIR" ln -sfn "$PREFIX/adb" "$BINDIR/adb"

if dpkg -s adb >/dev/null 2>&1; then
  echo "!!  Ubuntu's 'adb' package is also installed. Two adb versions fight over the"
  echo "    adb server ('server version doesn't match this client'). Remove it:"
  echo "      sudo apt remove adb"
fi

echo "==> installed"
"$BINDIR/scrcpy" --version | head -1
"$BINDIR/adb" version | head -1
echo "Optional, for hardware video decoding (scrcpy >= 5.0): sudo apt install va-driver-all"
