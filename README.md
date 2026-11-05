# phone-admin

Mirror, manage and (where the OS allows it) control **your own** Android phone and iPhone from an Ubuntu desktop. Everything is consent-based: every permission is granted by hand on the phone.

| | Android ([android/](android/README.md)) | iPhone ([ios/](ios/README.md)) |
|---|---|---|
| **See the screen, LAN** | scrcpy over USB or Wi-Fi | uxplay (AirPlay receiver), started from Control Center |
| **Control from the PC** | **Yes:** scrcpy (LAN), RustDesk (internet) | **No.** iOS has no input injection; view + manage only |
| **Over the internet** | RustDesk Android app on `rat.jami.uz` | The iPhone can *control* the Android phone (RustDesk iOS app), but it can't share its own screen |
| **Manage** | adb: apps, files, logs, screenshots, debloat | libimobiledevice over USB: info, apps, backups, files, screenshots |
| **Photo import** | `make android-photos` | `make ios-photos` |
| **Pairing** | USB debugging + RSA prompt on the phone | "Trust This Computer" + passcode on the phone |

## Quick start

```bash
make install            # scrcpy + adb, then uxplay + libimobiledevice (asks for sudo)
make doctor             # what's installed, running and attached, for both phones
make devices            # Android devices and iPhones

make android-mirror     # Android: mirror + control (scrcpy)
make ios-mirror         # iPhone: AirPlay receiver; then Control Center → Screen Mirroring → phone-admin
make ios-pair           # iPhone: tap "Trust" and enter the passcode on the phone

make android-photos DEST=~/Pictures/android    # copy only what's new; never deletes
make ios-photos DEST=~/Pictures/iphone
make ios-backup DIR=/media/backup               # checks free space before a first backup
```

Every target in [android/Makefile](android/Makefile) and [ios/Makefile](ios/Makefile) works from the root with an `android-` or `ios-` prefix. Their variables pass through too, e.g. `make android-mirror SERIAL=…` or `make ios-info UDID=…`. Relative paths such as `DEST=photos` or `APK=app.apk` are relative to the folder you ran `make` in, not to `android/` or `ios/`. Variables are only taken from the `make` command line, so a `PORT` or `NAME` exported in your shell doesn't change a target. You can also `cd android` or `cd ios` and run `make help`.

## RustDesk server: rat.jami.uz

Both halves use the self-hosted server `rat.jami.uz`, entered as ID server and relay server, plus the server's public key. Its IP is dynamic and DDNS keeps the name current, so always enter the hostname, never an IP.

- Android phone (shares its screen, can be controlled): [android/docs/RUSTDESK-ANDROID.md](android/docs/RUSTDESK-ANDROID.md)
- iPhone as the remote control: [ios/docs/RUSTDESK-IOS.md](ios/docs/RUSTDESK-IOS.md)

Sessions use RustDesk's built-in end-to-end encryption, with a fresh session key per connection. This project adds no crypto of its own.

## Layout

```
Makefile        install / doctor / devices / lint for both; forwards android-* and ios-*
android/        scrcpy, adb cheatsheet, Wi-Fi adb, redroid (virtual Android), RustDesk Android
ios/            uxplay mirroring, libimobiledevice cheatsheet, RustDesk iOS
```

`make lint` runs shellcheck on every script; if shellcheck isn't installed, it uses the Docker image.
