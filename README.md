# ios-viewer

View and manage **your own** iPhone from an Ubuntu desktop.

> **View + manage only, not remote control.** iOS does not let an outside computer inject touches or keystrokes, and this project does not try to get around that. You can watch the iPhone's screen on the PC and manage the device over USB, but you operate the phone on the phone.

- **View:** [uxplay](https://github.com/FDH2/UxPlay), an AirPlay receiver. You start Screen Mirroring from the iPhone's Control Center, and the picture shows up live on the PC. Wi-Fi/LAN only. → [docs/MIRROR.md](docs/MIRROR.md)
- **Manage:** [libimobiledevice](https://libimobiledevice.org) over USB: device info, app list/install, backups, screenshots, mounting the camera roll and app Documents folders. → [docs/MANAGE.md](docs/MANAGE.md)

The iPhone has to **trust this computer** (the "Trust This Computer?" prompt plus the passcode, tapped by you on the phone) before any management command works. That step can't be skipped.

## Quick start

```bash
make install       # uxplay + libimobiledevice-utils + ideviceinstaller + ifuse (Ubuntu packages)
make doctor        # what's installed, running and connected

# View: same Wi-Fi as the PC
make mirror        # then iPhone: Control Center → Screen Mirroring → "ios-viewer"

# Manage: USB cable, phone unlocked
make pair          # tap "Trust" and enter the passcode on the iPhone
make info          # model, iOS version, battery, storage
make backup        # into ./backups/<UDID>/
make screenshot    # needs Developer Mode; on iOS 17+ also `make install-pmd3` (docs/MANAGE.md#screenshots)
```

## Make targets

| Target | What it does |
|---|---|
| `install`, `install-mirror`, `install-manage` | Install everything, or just one half |
| `install-pmd3` | Optional pymobiledevice3 (pipx), needed for screenshots on iOS 17+ |
| `doctor` | Checks tools, Avahi, usbmuxd, pairing, iOS version and Developer Mode |
| `mirror`, `mirror-fs` | Start the AirPlay receiver (`NAME=…`, `OPTS="…"` for uxplay flags) |
| `devices`, `pair`, `unpair` | List iPhones; pair or unpair this PC |
| `info`, `apps`, `install-ipa IPA=…` | Device info; installed apps; install a signed `.ipa` |
| `backup`, `backup-full`, `backup-info` | Backups into `DIR` (default `./backups`) |
| `screenshot`, `dev-mode`, `mount-ddi` | Screenshot to `FILE`, plus the Developer Mode / disk image steps it needs |
| `mount`, `umount` | Mount or unmount the camera roll at `DIR` (default `./iphone-media`) |
| `syslog` | Live device log (`MATCH=…`) |
| `lint` | shellcheck the scripts |

Several iPhones attached: add `UDID=<udid>` (from `make devices`). `make help` lists all targets. `scripts/manage-cheatsheet.sh help` lists more commands: app Documents folders, crash logs, encryption, restore, rename, restart.

## iOS-version notes (details in the docs)

- **iOS 16 and later:** screenshots need **Developer Mode**, which you switch on yourself on the phone.
- **iOS 17 and later:** Ubuntu 24.04's libimobiledevice 1.3.0 can't reach developer services (screenshots), so use pymobiledevice3. iOS 17.0–17.3 also need `sudo pymobiledevice3 remote tunneld`.
- **iOS 11.4.1 and later:** USB Restricted Mode blocks USB data after an hour locked. Unlock the phone first.
- **Mirroring:** DRM-protected video shows black. After iOS updates, an older uxplay may need upgrading.

## Layout

```
scripts/install.sh            apt install (+ optional pymobiledevice3, ufw ports); --dry-run, --help
scripts/mirror.sh             preflight checks, then uxplay -n NAME -nh -p
scripts/manage-cheatsheet.sh  one small function per management task; `help` lists them
docs/MIRROR.md                uxplay setup, iPhone Screen Mirroring steps, troubleshooting
docs/MANAGE.md                pairing, commands, backups, files, screenshots by iOS version
```

The Android counterpart, which *can* control the phone because Android allows it, is `../androidMonitor` ([android-admin](https://github.com/kool277/android-admin)).
