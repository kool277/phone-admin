# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Bash scripts, a Makefile and docs for viewing and managing the owner's own iPhone from Ubuntu: uxplay (AirPlay receiver) for live mirroring, libimobiledevice over USB for management, and docs for using the RustDesk iOS app (server `rat.jami.uz`) to control the Android phone set up in `../android`. **View + manage only.** iOS offers no input injection from a computer, so never add anything that tries to control the phone or works around Apple's restrictions. The same goes for the "Trust This Computer" pairing, Developer Mode and app signing: document these steps and leave them manual. This is the `ios/` half of the phone-admin repo; the Android half is `../android`, and the root `Makefile` forwards `ios-<target>` here. Its style (cmd_ functions, `## ` help comments, `make help`) is mirrored here.

## Commands

```bash
make help                                   # targets, generated from the "## " comments in Makefile
make lint                                   # shellcheck scripts/*.sh — keep it clean
scripts/manage-cheatsheet.sh help           # commands, generated from the "## " comments above cmd_* functions
scripts/install.sh --dry-run                # print the apt/systemctl/ufw/pipx commands without running them
```

## How the pieces fit

- `manage-cheatsheet.sh` dispatches `cmd_<name>`. The `## name ARGS — description` comment above each one is the help text. Device-touching commands call `need_paired`, which requires exactly one USB iPhone (or the `UDID` env var) and a valid pairing. `UDID` becomes `-u` for libimobiledevice/ifuse and `PYMOBILEDEVICE3_UDID` for pymobiledevice3. Don't add per-command device plumbing.
- `ifuse` takes the mount point **first**, then options (`ifuse DIR -u UDID --documents ID`).
- Help text for `install.sh`, `mirror.sh` and the cheatsheet is printed from the leading `#` comment block, so keep those headers user-facing.
- `photos` mounts the media area on a temp dir with an EXIT trap that unmounts it, then `rsync -rt --ignore-existing`. Keep it non-destructive: never `--delete`, never overwrite.
- `backup` calls `backup_space_check` for first and `FULL=1` backups (phone's used storage vs `df` of DIR; `FORCE=1` overrides).
- `mirror.sh` always runs `uxplay -p` (fixed ports TCP 7000/7001/7100, UDP 6000/6001/7011). The docs and `install.sh --ufw` rely on those ports.

## Facts the docs rely on

Checked against Ubuntu 24.04 packages (uxplay 1.68.2, libimobiledevice 1.3.0, ideviceinstaller 1.1.1, ifuse 1.1.4) and pymobiledevice3 11.49. Re-check when these change:

- libimobiledevice 1.3.0 can't reach developer services (screenshots) on iOS 17+. pymobiledevice3 does: `developer dvt screenshot OUT`, `mounter auto-mount`, `amfi reveal-developer-mode`. 11.x opens a no-root userspace tunnel on iOS 17.4+. iOS 17.0–17.3 need `sudo pymobiledevice3 remote tunneld`.
- Developer Mode status: lockdown domain `com.apple.security.mac.amfi`, key `DeveloperModeStatus` (iOS 16+).
- RustDesk 1.5.1 iOS app is outgoing-only: `flutter/lib/mobile/pages/home_page.dart` adds the share-screen `ServerPage` only `if (isAndroid …)`, and `flutter/ios/` has no broadcast extension. Docs must not claim the iPhone can share its screen via RustDesk; re-check on RustDesk upgrades. Server: `rat.jami.uz` (DDNS). Docs use the hostname, never an IP, and never contain the key's value.
- ideviceinstaller 1.1.1 uses the old flag syntax (`-l -o list_user`, `-i`, `-U`). Newer upstream versions use subcommands.
