# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Bash scripts, a Makefile and docs for administering the owner's own Android devices from Ubuntu. scrcpy covers USB and LAN access. The RustDesk Android client, pointed at a self-hosted server (from the separate `rustdesk-core` project), covers internet access. Every phone-side permission is granted by hand on the device, so keep it that way: scripts may automate the PC side and optional adb shortcuts, but must not bypass on-device consent prompts.

## Commands

```bash
make help          # all targets (generated from the "## " comments in Makefile)
make lint          # shellcheck scripts/*.sh (Docker image if shellcheck is missing) — keep it clean
scripts/adb-cheatsheet.sh help
scripts/wireless.sh help
```

To test the installer without root or touching the system:
`SCRCPY_PREFIX=/tmp/x/opt SCRCPY_BINDIR=/tmp/x/bin scripts/install.sh --no-deps`

## How the pieces fit

- `install.sh` installs the **official static scrcpy release** into `/opt/scrcpy` (`SCRCPY_PREFIX`; never read plain `PREFIX`, users export it for other builds). It `rm -rf`s that folder on every install, so it refuses one that isn't empty and has no `scrcpy-server`. Its sudo decision (`as_root_in DIR`) always tests the directory being changed, never a file or symlink in it. The `/usr/local/bin/scrcpy` it creates is a *wrapper script*, not a symlink, so that scrcpy finds `scrcpy-server` next to it. The bundled `adb` is symlinked as `/usr/local/bin/adb`, so the shell and scrcpy share one adb server version. Ubuntu's `adb` package conflicts with this; the script warns about it.
- Device selection goes through the `ANDROID_SERIAL` env var, which adb and scrcpy both honor. The Makefile exports it from `SERIAL=`. Don't add `-s` plumbing to scripts.
- `adb-cheatsheet.sh` dispatches `cmd_<name>` functions. The `## name ARGS — description` comment above each function is what `help` prints, so add new commands in that form. Every command except `help`, `devices` and `doctor` requires exactly one connected device (the dispatcher at the bottom enforces it; `doctor` reports device problems itself).
- `redroid.sh` runs Android in Docker for testing without a phone (the dev host has no KVM, so the Android Emulator isn't an option). adb reaches it at `127.0.0.1:5600`. Keep that port outside 5555–5585, which adb probes for emulators.
- Help text for `install.sh` and `wireless.sh` is printed by `sed -n 'A,Bp' "$0"` from their header comments. If you edit a header, update the line range too.
- `adb shell` joins its arguments into one command line for the phone's shell, so quote anything user-supplied with `sq` (see `type`, `photos`).
- `rustdesk-perms` only whitelists battery and *reads* the accessibility setting. Never write `enabled_accessibility_services` or other consent settings over adb.
- Check success explicitly where `set -e` can't see failures: `a && b` lists, and adb commands that exit 0 on failure (`adb pair`, `adb connect`; match their output).
- `photos` lists files once (`mapfile`), skips hidden paths (Android 11+ `.trashed-*`/`.pending-*`, `.thumbnails`), pulls each new file with `adb pull -a` to `.part` then `mv`; a failed pull is reported, its `.part` removed, and the run exits non-zero. Inside loops, give adb `</dev/null` or it swallows the loop's stdin. Keep it non-destructive.
- The scripts use `set -euo pipefail`. Don't pipe `curl` into `grep -m1`/`head`: the early pipe close kills curl (exit 23). Capture the response into a variable first.

## Facts the docs rely on

The docs were last checked against scrcpy 5.0.1 and RustDesk 1.5.1. Re-check version-specific claims when bumping.

- RustDesk server host: `rat.jami.uz` (DDNS, dynamic IP). Docs always use the hostname, never an IP, and never contain the key's value: they show how to read `id_ed25519.pub` instead.
- RustDesk Android package: `com.carriez.flutter_hbb`; accessibility service: `com.carriez.flutter_hbb/com.carriez.flutter_hbb.InputService`.
- RustDesk APK asset names: `rustdesk-<ver>-{aarch64,armv7,x86_64,universal}-signed.apk`.
- scrcpy Linux asset: `scrcpy-linux-x86_64-<tag>.tar.gz` (contains `scrcpy`, `scrcpy-server`, `adb`), checked against `SHA256SUMS.txt`.
