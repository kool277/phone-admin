# android-admin

Control **your own** Android devices from an Ubuntu desktop. You get full screen, keyboard and mouse control in two ways:

- **On the local network:** [scrcpy](https://github.com/Genymobile/scrcpy) over USB or Wi-Fi. It needs no app on the phone and has low latency.
- **Over the internet:** the [RustDesk](https://github.com/rustdesk/rustdesk) Android app, pointed at your own self-hosted RustDesk server.

Everything is consent-based. Developer options, USB debugging, the RSA prompt, screen capture and the accessibility toggle are all enabled by hand on the phone.

## Quick start

```bash
make install            # scrcpy + adb + udev rules (then log out/in once)
# phone: enable Developer options + USB debugging, plug in, accept the prompt
make mirror-usb         # mirror + control over USB
make mirror-tcpip       # switch the USB phone to Wi-Fi and mirror wirelessly
```

Android 11+ without a cable:

```bash
make pair ADDR=192.168.1.42:37123 CODE=482915   # once (Wireless debugging → pair)
make connect ADDR=192.168.1.42:41245            # port from the Wireless debugging screen
make mirror-wifi
```

Remote control over the internet through your RustDesk server:

```bash
make rustdesk-android   # install the right APK for the phone's CPU
# then follow docs/RUSTDESK-ANDROID.md on the phone
```

## Make targets

| Target | What it does |
|---|---|
| `install` / `install-apt` | Install scrcpy + adb: the official release, or Ubuntu's older packages |
| `mirror`, `mirror-usb`, `mirror-wifi` | Run scrcpy (any device, USB only, TCP only) |
| `mirror-tcpip [IP=…]` | `scrcpy --tcpip`: switch a USB phone to Wi-Fi, or connect to an IP |
| `desktop [SIZE=…]` | Separate virtual display on the phone (Android 10+) |
| `record [FILE=…]` | Record the screen to MP4 without opening a window |
| `pair`, `connect`, `wireless`, `disconnect` | Wi-Fi adb helpers (`scripts/wireless.sh`) |
| `install-apk APK=…` | Install or update an APK and keep its data |
| `devices`, `info` | List devices; model, Android version, battery, storage |
| `rustdesk-android`, `rustdesk-perms` | Install RustDesk; optional battery and input permissions via adb |

Common variables: `SERIAL=<serial|ip:port>` picks a device; `OPTS="…"` passes extra scrcpy flags. `make help` lists all targets.

More adb commands, such as packages, debloat/restore, pulling APKs, push/pull files, logcat, screenshots and reboot:

```bash
scripts/adb-cheatsheet.sh help
```

## Layout

```
scripts/install.sh          scrcpy (official static build, bundles adb) + udev rules
scripts/wireless.sh         adb pair / connect / tcpip / mDNS discover
scripts/adb-cheatsheet.sh   commented adb management commands, runnable by name
docs/SCRCPY.md              phone prep, USB + Wi-Fi, options, shortcuts, per-version notes
docs/RUSTDESK-ANDROID.md    client config (ID/Relay/Key), permissions, unattended access
```

## Notes

- **Audio:** scrcpy forwards audio itself on Android 11+, so sndcpy isn't needed.
- **Don't expose adb to the internet.** Use RustDesk (or a VPN) for remote access. adb over TCP gives a full shell to anyone who can reach the port.
- **RustDesk server values** (host and public key) come from your `rustdesk-core` server. The docs use `rd.example.com` as a placeholder.
