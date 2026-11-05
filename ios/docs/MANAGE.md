# Managing the iPhone over USB (libimobiledevice)

[libimobiledevice](https://libimobiledevice.org) speaks the same USB protocols as Finder/iTunes: device info, app install and list, backups, file access, logs. It **manages** the phone. It can't control it, because iOS doesn't let a computer send touches or keys.

All commands are in `scripts/manage-cheatsheet.sh` (`help` lists them). The common ones also have `make` targets. With several iPhones attached, add `UDID=…`; `make devices` shows the UDIDs.

Checked against Ubuntu 24.04's packages: libimobiledevice 1.3.0, ideviceinstaller 1.1.1, ifuse 1.1.4, usbmuxd 1.1.1. The optional pymobiledevice3 was checked at version 11.49.

## Pairing: "Trust This Computer" (required)

Every command first needs the iPhone to trust this PC. This happens **on the phone, by you**. It can't be skipped or automated, and nothing here tries to.

```bash
make pair
```

1. Connect the USB cable and **unlock** the iPhone.
2. The iPhone asks **"Trust This Computer?"**. Tap **Trust**.
3. Enter the iPhone **passcode**.
4. `make pair` waits up to 2 minutes and prints `paired`.

What to know:

- **Pair record.** usbmuxd saves the pairing in `/var/lib/lockdown/` on the PC. Those files grant access to the phone, so treat them like a password.
- **Revoking trust.** `make unpair` removes this PC. On the iPhone, Settings → General → Transfer or Reset iPhone → Reset → **Reset Location & Privacy** forgets *all* trusted computers.
- **If you tapped Don't Trust**, unplug and replug the cable to see the prompt again.
- **After a restart** the iPhone has to be unlocked once before USB management works.
- **USB Restricted Mode** (iOS 11.4.1 and later): if the iPhone has been locked for more than an hour, USB data stops until you unlock it. Unlock the phone before running commands. The setting is under Settings → Face ID/Touch ID & Passcode → "Accessories".

## Everyday commands

| make / cheatsheet | Tool | What it does |
|---|---|---|
| `make doctor` | | Checks tools, Avahi, usbmuxd, pairing, iOS version and Developer Mode; with `UDID=…`, that this iPhone is attached |
| `make devices` | `idevice_id -l` | UDIDs and names on USB |
| `make info` | `ideviceinfo` | Name, model, iOS version, battery, storage, Developer Mode |
| `info-all [DOMAIN]` | `ideviceinfo [-q DOMAIN]` | Every lockdown value, e.g. `com.apple.mobile.battery` |
| `make apps [FILTER=…]` | `ideviceinstaller -l` | User apps as CSV: bundle id, version, name (`-o list_all` for system apps) |
| `make install-ipa IPA=…` | `ideviceinstaller -i` | Install or upgrade an `.ipa` (see signing below) |
| `uninstall BUNDLEID` | `ideviceinstaller -U` | Remove an app and its data |
| `make backup [DIR=…]` | `idevicebackup2 backup` | Incremental backup into `DIR/<UDID>/`; `make backup-full` forces a full one |
| `make backup-info` | `idevicebackup2 info` | Summary of the last backup |
| `backup-encryption on\|off` | `idevicebackup2 -i encryption` | Encrypt backups (password prompt; not on the command line) |
| `restore [DIR]` | `idevicebackup2 restore` | Put a backup back on the phone (asks first) |
| `make screenshot` | pymobiledevice3 / `idevicescreenshot` | See [Screenshots](#screenshots) |
| `make photos [DEST=…]` | `ifuse` + `rsync` | Copy new photos/videos to `./photos`; re-runs copy only what's new, nothing is deleted |
| `make mount [DIR=…]` | `ifuse` | Mount the camera roll/media area (`DCIM/`, …) |
| `shared-apps` | `ifuse --list-apps` | Apps whose Documents folder can be mounted |
| `mount-docs BUNDLEID [DIR]` | `ifuse --documents` | Mount one app's Documents folder |
| `make umount [DIR=…]` | `fusermount -u` | Unmount |
| `make syslog [MATCH=…]` | `idevicesyslog -q` | Live device log |
| `crashlogs [DIR]` | `idevicecrashreport -k -e` | Copy crash reports, leaving them on the phone |
| `name [NEW]` | `idevicename` | Show or rename the iPhone |
| `restart`, `shutdown` | `idevicediagnostics` | Restart or power off |

## Backups

- Backups use the same format as Finder/iTunes and land in `DIR/<UDID>/`. The size is roughly the phone's used storage, minus what lives only in iCloud.
- **Free space check:** a first backup (or `make backup-full`) needs room for all of that, and running out halfway wastes a long wait. `make backup` compares the phone's used storage with the free space in `DIR` first and refuses if it won't fit. The phone's usage is an upper bound, so `FORCE=1` tries anyway. Later backups are incremental and skip the check. External disk: `make backup DIR="/media/$USER/<disk>/iphone"` (quote it if the disk name has spaces).
- **Encryption:** encrypted backups also keep saved passwords, Wi-Fi, Health and call history. On iOS 13 and later, turning encryption on or off asks for the passcode on the phone. When encryption is on, starting a backup may ask for it as well. The password is stored on the iPhone, and if you lose it, the backups can't be read. Removing it without the password means resetting all settings on the phone.
- **Restore** replaces the phone's data and reboots it. iOS refuses while **Find My iPhone** is on.

## Installing apps

iOS only installs apps that are **signed for it**: App Store/TestFlight builds, or your own development or ad-hoc builds that list this device's UDID. Any other `.ipa` fails with a signature or provisioning error. That restriction is part of iOS, and this project doesn't work around it.

## File access (ifuse)

- `make mount` exposes the **media area**: `DCIM/` (photos and videos as HEIC/HEVC or JPEG/H.264, depending on Settings → Camera → Formats), plus a few others. With iCloud Photos set to "Optimize iPhone Storage", many originals aren't on the phone at all.
- `mount-docs` works only for apps that turned on **File Sharing**. `scripts/manage-cheatsheet.sh shared-apps` lists them. `ifuse --container` (the whole app sandbox) works only for development-signed apps. `--root` needs a jailbreak and isn't used here.
- Unmount before you unplug: `make umount`.
- **Importing photos:** `make photos DEST=~/Pictures/iphone` mounts the camera roll, copies files that aren't in `DEST` yet (keeping the folder layout and capture times), and always unmounts afterwards, even on Ctrl+C. It never deletes anything on the phone or the PC, so you can run it whenever you like. To view HEIC/HEVC on Ubuntu: `sudo apt install heif-gdk-pixbuf heif-thumbnailer`.

## Screenshots

The screenshot service is a **developer service**. Developer Mode has to be on (iOS 16 and later), and a Developer Disk Image (DDI) has to be mounted. How you get there depends on the iOS version:

| iOS | What works |
|---|---|
| ≤ 15 | `idevicescreenshot` (TIFF) after mounting the DDI for that exact iOS version (`ideviceimagemounter` with the image from Xcode, or `make mount-ddi`) |
| 16 | Same, plus Developer Mode must be on |
| 17 and later | Developer services moved to a new tunnel (RemoteXPC) and a *personalized* DDI. **Ubuntu's libimobiledevice 1.3.0 can't do this. Use pymobiledevice3.** |

With pymobiledevice3 (every iOS version):

```bash
make install-pmd3    # pipx install pymobiledevice3 (user-level); re-run later to upgrade it
make dev-mode        # iOS 16+: makes the switch visible. Then, ON THE PHONE:
                     #   Settings → Privacy & Security → Developer Mode → On → Restart → confirm with passcode
make mount-ddi       # pymobiledevice3 mounter auto-mount: downloads the right image (internet needed;
                     #   iOS 17+ images are personalized through Apple's signing server)
make screenshot      # pymobiledevice3 developer dvt screenshot → PNG
```

- **Tunnel, iOS 17.4 and later:** pymobiledevice3 (11.x) opens its own tunnel without root, automatically.
- **Tunnel, iOS 17.0–17.3:** start `sudo pymobiledevice3 remote tunneld` in another terminal and export `PYMOBILEDEVICE3_TUNNEL=<udid>`.
- **iOS 27:** pymobiledevice3 11.x's source notes that the developer image becomes a *cryptex* from iOS 27 on. After every major iOS update, run `make install-pmd3` (it upgrades an existing install) before anything else.
- **Turning it off:** Developer Mode loosens a few protections, so switch it off again when you're done (same settings screen).
- **Without Developer Mode:** mirror the screen (`make mirror`) and take a screenshot of the uxplay window with the desktop's own screenshot tool. This works on any iOS version.

## libimobiledevice version caveat

Ubuntu 24.04 ships libimobiledevice **1.3.0, from June 2020**. Upstream released 1.4.0 in October 2025. The lockdown services used above (info, pairing, apps, backup, files, syslog) are long-standing. The developer services (screenshots) are what broke with iOS 17. If a command fails on a new iOS release, try the pymobiledevice3 equivalent before debugging:

```bash
pymobiledevice3 apps list --type User
pymobiledevice3 apps install app.ipa
pymobiledevice3 backup2 backup --full backups/
```
