# Screen mirroring with uxplay

> **View only.** AirPlay Screen Mirroring sends the iPhone's picture and sound *to* this PC and nothing comes back. Clicking or typing in the uxplay window does nothing on the phone. iOS has no way for an outside computer to inject touches or keys, and this project doesn't try to get around that. To operate the phone, use the phone.

[uxplay](https://github.com/FDH2/UxPlay) is an open-source AirPlay receiver. The iPhone sees it as one more Apple TV-like target in its Screen Mirroring list.

Checked against uxplay 1.68.2 (Ubuntu 24.04's package). Run `uxplay -h` for the options of the version you have.

## Requirements

- **Same local network.** The iPhone and the PC must be on the same LAN/subnet. The iPhone finds receivers through Bonjour (mDNS, UDP 5353), which doesn't cross routers. Guest Wi-Fi and networks with "client/AP isolation" block it. Mirroring works over Wi-Fi only, not over the USB cable.
- **Avahi running** on the PC (`avahi-daemon`): `scripts/install.sh` enables it.
- **A desktop session** (X11 or Wayland) to show the window.
- **Firewall:** if ufw is on, open the fixed ports that `scripts/mirror.sh` makes uxplay use (`-p`): TCP 7000, 7001, 7100 and UDP 6000, 6001, 7011, plus UDP 5353. `scripts/install.sh --no-mirror --no-manage --ufw` adds exactly those rules.

## Set up the PC

```bash
make install-mirror       # uxplay, GStreamer decoders, avahi-daemon
make mirror               # starts uxplay as "ios-viewer"; Ctrl+C stops it
make mirror NAME="Office PC" OPTS="-fs"
```

`scripts/mirror.sh` checks that uxplay and Avahi are ready, then runs `uxplay -n "$NAME" -nh -p` with your extra options.

## Mirror from the iPhone

1. Open **Control Center**. On iPhones with Face ID, swipe down from the top-right corner. On iPhones with a Home button, swipe up from the bottom edge.
2. Tap **Screen Mirroring** (two overlapping rectangles).
3. Pick **ios-viewer** (or your `NAME`). If you started uxplay with `-pin`, type the code shown on the PC.
4. To stop: Control Center → Screen Mirroring → **Stop Mirroring**, or Ctrl+C in the terminal.

If the screen is rotated, the picture follows. `-r R|L` rotates the window and `-f H|V|I` flips it.

## Useful uxplay options

Pass them as `make mirror OPTS="…"` or `scripts/mirror.sh …`.

| Option | Effect |
|---|---|
| `-fs` | Full screen (X11 and Wayland) |
| `-s 2560x1440@60` | Resolution and refresh rate reported to the iPhone (default 1920x1080@60) |
| `-fps 60` | Allow up to 60 fps (default 30) |
| `-pin 1234` / `-pin` | Require a fixed 4-digit code, or a random one per connection |
| `-reg` | With `-pin`: remember devices that entered the code (`~/.uxplay.register`) |
| `-restrict -allow <id>` | Accept only listed device IDs (shown in uxplay's log) |
| `-nohold` | A new connection replaces the current one |
| `-as 0` | No audio, video only |
| `-avdec` | Software H.264 decoding, when hardware decoding misbehaves |
| `-vsync no` | Turn off audio/video sync, if video stutters behind audio |
| `-nc` | Keep the window open when the iPhone stops mirroring |

## Behavior that depends on iOS and apps

- **Protected video shows black.** Apps that use DRM, like many streaming services, block mirroring of their video. Some apps also hide sensitive screens. This comes from the app and iOS, not uxplay.
- **Control Center layout.** iOS 18 made Control Center customizable. If Screen Mirroring is missing, add it back: open Control Center → **+** → **Add a Control** → Screen Mirroring.
- **Newer iOS, older uxplay.** Ubuntu 24.04's uxplay (1.68.2) is older than upstream. If a new iOS release won't connect or shows artifacts, build the current release from <https://github.com/FDH2/UxPlay> before you debug anything else.

## Troubleshooting

| Symptom | Check |
|---|---|
| "ios-viewer" doesn't appear on the iPhone | `systemctl status avahi-daemon`; same subnet (no guest Wi-Fi); firewall ports above; `avahi-browse -rt _airplay._tcp` (package `avahi-utils`) should list it |
| Appears, but connecting fails or hangs | Firewall: the TCP/UDP ports above; restart uxplay; `-d` for a debug log |
| Black or green window, or a GStreamer error | `OPTS="-avdec"`; make sure `gstreamer1.0-libav` and `gstreamer1.0-plugins-bad` are installed |
| Laggy | 5 GHz Wi-Fi or Ethernet for the PC; `-fps 30`; lower `-s` |
| Only sound, no picture | You chose AirPlay audio from an app, not Screen Mirroring from Control Center |
