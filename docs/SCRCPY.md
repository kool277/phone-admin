# scrcpy: mirror and control over USB or Wi-Fi

[scrcpy](https://github.com/Genymobile/scrcpy) mirrors the phone's screen to a window on Ubuntu and sends your keyboard and mouse back to the phone. It needs no app on the phone and no root, only adb with USB debugging. These notes were checked against **scrcpy 5.0.1** (adb 37) in November 2026.

## What works on which Android version

| Feature | Minimum Android |
|---|---|
| Mirroring + control | 5.0 |
| Wireless debugging with a pairing code (`adb pair`) | 11 |
| Audio forwarding (built into scrcpy, so no sndcpy needed) | 11 |
| Virtual display (`--new-display`) | 10 |
| Camera mirroring (`--video-source=camera`) | 12 |
| Copy/paste shortcuts (`MOD+c/x/v`) | 7 |

## 1. Install on Ubuntu

```bash
make install        # official static release → /opt/scrcpy, plus adb, plus udev rules
```

- The release bundles a current `adb`. `install.sh` links it as `/usr/local/bin/adb` so that scrcpy and your shell use the same adb server. If Ubuntu's `adb` package is also installed, the two versions keep restarting each other's server ("adb server version doesn't match this client"). Fix it with `sudo apt remove adb`.
- `make install-apt` installs Ubuntu's packages instead. On 24.04 that means scrcpy 1.25, which has no audio, no virtual display and no UHID keyboard. It's only worth using on non-x86_64 machines.
- To use hardware video decoding (on by default since scrcpy 5.0), run `sudo apt install va-driver-all`. scrcpy falls back to software decoding when it's missing.
- After the first install, **log out and back in** so that the `plugdev` group (for USB access) takes effect.

## 2. Prepare the phone (once, by hand)

1. **Enable Developer options.** Go to *Settings → About phone* and tap **Build number** 7 times. The location varies by brand:
   - Samsung: *About phone → Software information → Build number*
   - Xiaomi/Redmi/POCO: *About phone → OS version* (tap the MIUI or HyperOS version)
   - Pixel / AOSP: *About phone → Build number*
2. Open *Settings → System → Developer options* (Samsung: at the bottom of Settings) and turn on **USB debugging**.
3. **Xiaomi / HyperOS only:** also enable **USB debugging (Security settings)**. Without it, mirroring works but clicks and typing do nothing. Some OPPO/realme/OnePlus (ColorOS) builds need **Disable permission monitoring** turned on for the same reason.
4. Plug in the USB cable and, on the phone, accept **Allow USB debugging?**. Tick *Always allow from this computer*.

Check with `adb devices -l`. The phone should show as `device`, not `unauthorized`.

## 3. Mirror over USB

```bash
make mirror-usb                 # = scrcpy -d
scrcpy -d --max-size=1600       # lower resolution if the link is slow
```

## 4. Mirror over Wi-Fi

The phone and the PC must be on the same LAN.

### A. Android 11+: Wireless debugging (no cable at all)

1. Go to *Developer options → **Wireless debugging*** → turn it on → **Pair device with pairing code**. The phone shows an `IP:PORT` and a 6-digit code.
2. On Ubuntu:
   ```bash
   make pair ADDR=192.168.1.42:37123 CODE=482915     # once per PC
   ```
3. Back on the main *Wireless debugging* screen, use the **IP address & Port** shown there. That's a *different* port from the pairing one.
   ```bash
   make connect ADDR=192.168.1.42:41245
   make mirror-wifi                                   # = scrcpy -e
   ```
`scripts/wireless.sh discover` lists phones advertising themselves over mDNS, which saves reading the port off the screen.

This mode has some quirks. The connect port changes every time Wireless debugging is toggled or the phone reboots. Android also switches Wireless debugging off when you leave the network it was turned on for.

### B. Any version: `adb tcpip` (USB first, then unplug)

```bash
make wireless                   # phone on USB: finds its Wi-Fi IP, runs adb tcpip 5555, connects
make mirror-wifi
```
Or let scrcpy do it all in one step:
```bash
make mirror-tcpip               # = scrcpy --tcpip   (phone on USB)
make mirror-tcpip IP=192.168.1.42   # already in tcpip mode: just connect
```
TCP mode lasts until the phone reboots. After a reboot, plug in the cable and repeat.

Don't expose adb (port 5555 or the wireless debugging port) to the internet: anyone who reaches it can run commands on the phone. For access over the internet, use RustDesk ([RUSTDESK-ANDROID.md](RUSTDESK-ANDROID.md)), or run adb through a VPN or SSH tunnel.

## 5. Useful options

| Goal | Flag |
|---|---|
| Lower resolution / bitrate on slow Wi-Fi | `-m 1280 -b 4M --max-fps=30` |
| Better compression (if the phone supports it) | `--video-codec=h265` |
| Phone screen off while you control it | `-S` / `--turn-screen-off` |
| Keep phone awake while plugged in / always | `-w` / `--keep-active` |
| Physical-keyboard behaviour (layouts, IME, games) | `-K` (UHID keyboard), `-M` (UHID mouse) |
| No audio / mic instead of phone audio | `--no-audio` / `--audio-source=mic` |
| Second "desktop" on the phone | `--new-display=1920x1080` (+ `--start-app=org.mozilla.firefox`) |
| Record to a file | `--record=file.mp4` (add `--no-playback` for no window) |
| Read-only view | `-n` / `--no-control` |
| Lock phone when you close scrcpy | `--power-off-on-close` |
| Webcam use (v4l2loopback) | `--v4l2-sink=/dev/video2 --no-playback` |

Pass extra flags through make: `make mirror-wifi OPTS="-m 1280 -S"`. With several phones connected, pick one with `SERIAL=`, e.g. `make mirror SERIAL=R58M123ABC`.

## 6. Shortcuts (MOD = left Alt or left Super)

| Keys | Action |
|---|---|
| `MOD+h` / middle-click | Home |
| `MOD+b` / right-click | Back |
| `MOD+s` | Recent apps |
| `MOD+p` | Power |
| `MOD+o` / `MOD+Shift+o` | Phone screen off / on (keeps mirroring) |
| `MOD+n` / `MOD+Shift+n` | Expand / collapse notifications |
| `MOD+r` | Rotate phone |
| `MOD+f` / `F11` | Fullscreen |
| `MOD+v` | Paste PC clipboard on phone |
| `MOD+q` | Quit |
| Drag an `.apk` onto the window | Install it |
| Drag any other file | Push it to `/sdcard/Download/` |

For the full list, run `man -l /opt/scrcpy/scrcpy.1` or `scrcpy --help`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `unauthorized` | Accept the prompt on the phone. If none appears: *Developer options → Revoke USB debugging authorizations*, replug |
| `no permissions (missing udev rules? user is in the plugdev group)` | Log out and back in after `make install`. Check that `id` lists `plugdev` |
| `adb server version (...) doesn't match this client` | `sudo apt remove adb`, then use `/usr/local/bin/adb` |
| Mirror works but input doesn't | Xiaomi: *USB debugging (Security settings)*. ColorOS: *Disable permission monitoring* |
| Some apps show black | Normal: banking/DRM apps block capture (`FLAG_SECURE`) |
| Laggy over Wi-Fi | `-m 1024 -b 2M --max-fps=30`, use 5 GHz Wi-Fi, or USB |
| Need to list devices | `make devices` |
