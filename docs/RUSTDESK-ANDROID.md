# RustDesk on Android: remote control through your own server

This sets up the RustDesk Android app so you can control the phone from Ubuntu over the internet. All traffic goes through **your** self-hosted server from the `rustdesk-core` project, not RustDesk's public servers. Every permission is granted by hand on the phone. Checked against **RustDesk 1.5.1**.

## What you need from rustdesk-core

| Value | Where it comes from | Example |
|---|---|---|
| Server host | Your domain or public IP running `hbbs` + `hbbr` | `rd.example.com` |
| Public key | Contents of `id_ed25519.pub` in the hbbs data directory | `AbC…xyz=` (44 chars) |

The server must accept **TCP 21115–21117 and UDP 21116**. Ports 21118 and 21119 are only needed for the web client.

## 1. Install the app

With the phone attached over adb (see [SCRCPY.md](SCRCPY.md)):

```bash
make rustdesk-android     # downloads the latest APK for the phone's CPU from GitHub and installs it
```

You can also install it from [GitHub releases](https://github.com/rustdesk/rustdesk/releases) or F-Droid. Package name: `com.carriez.flutter_hbb`.

## 2. Point it at your server (on the phone)

1. Open RustDesk → **Settings** tab → **ID/Relay Server**.
2. Fill in:
   - **ID Server:** `rd.example.com`
   - **Relay Server:** `rd.example.com` (if left empty, it uses the ID server host on port 21117)
   - **API Server:** leave empty (only used by RustDesk Server Pro)
   - **Key:** paste the public key
3. Save. The **Share screen** tab should now show the device's **ID** and a ready status. If it says "not ready", check the host, the firewall and the key.

## 3. Grant screen capture and input (on the phone)

On the **Share screen** tab:

1. Tap **Start service**. Android asks to start screen capture; choose **Start now**.
   - **Android 14+** asks *"A single app"* or *"Entire screen"*. Pick **Entire screen**.
2. Under **Permissions**, turn on **Input Control**. This opens Android's Accessibility settings. Go to *Installed apps* (also called *Downloaded apps* / *Installed services*), choose **RustDesk Input**, and turn it **On**.
   - **Android 13+, app installed via adb or browser:** the switch may be greyed out with *"Restricted setting"*. Go to *Settings → Apps → RustDesk*, tap **⋮ → Allow restricted settings**, confirm with your PIN, then try again.
3. Optional: **File Transfer** (asks for storage access) and audio capture (Android 10+).

## 4. Make it unattended

Unattended means you can connect without anyone accepting the connection on the phone.

| Setting | Where |
|---|---|
| **Set permanent password** (long and unique) | Settings → Security |
| **Accept sessions via password** (not "via click") | Settings → Security |
| **Ignore Battery Optimizations** → choose *Unrestricted* | Settings (or *Android Settings → Apps → RustDesk → Battery*) |
| **Keep RustDesk background service** | Settings |
| **Start on boot** (needs *Display over other apps*) | Settings |
| Allow **notifications** (Android 13+) | Prompted on first start; the foreground service needs them |

Phone makers' battery killers also turn the service off. Check these:
- **Samsung:** *Battery → Background usage limits*. Make sure RustDesk is **not** in *Sleeping* or *Deep sleeping apps*.
- **Xiaomi/HyperOS:** *App info → Autostart* **on**, *Battery saver* → **No restrictions**.
- **Huawei/Honor:** *App launch* → manage RustDesk manually and allow all three toggles.

### Optional: do the battery exemption and input toggle over adb

You can do the Ignore Battery Optimizations and Input Control steps from Ubuntu instead. The phone needs USB debugging on (it's yours, and you turned it on):

```bash
make rustdesk-perms
```

This runs `dumpsys deviceidle whitelist +com.carriez.flutter_hbb`. It also adds `com.carriez.flutter_hbb/com.carriez.flutter_hbb.InputService` to `enabled_accessibility_services`, keeping any services already listed there. It skips the Android 13+ "restricted setting" dialog. It **cannot** grant screen capture; that has to be tapped on the phone.

### Hard limit: screen capture needs a tap after every restart

Android doesn't let an ordinary app keep screen-capture permission across restarts of its capture service. If the phone reboots, or the system kills RustDesk, someone has to tap **Start now** on the phone before you can see the screen again. Android 14+ is stricter still: consent is per capture session. *Start on boot* plus the battery exemptions above make this rare, but they can't eliminate it. When that happens, use scrcpy over the LAN (or an adb-over-VPN session) to tap it yourself.

## 5. Connect from Ubuntu

```bash
v=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4)
curl -fLO "https://github.com/rustdesk/rustdesk/releases/download/$v/rustdesk-$v-x86_64.deb"
sudo apt install "./rustdesk-$v-x86_64.deb"
```

1. In the desktop client, open **Settings → Network → ID/Relay Server** and enter the **same** ID Server, Relay Server and Key.
2. Enter the phone's ID, choose **Connect**, and type the permanent password.
3. Controls: left-click = tap, right-click = back. Home and recents are in the toolbar at the top of the session window.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Key mismatch" / "Failed to secure connection" | Key differs between the phone, the PC and `id_ed25519.pub`; re-paste it everywhere |
| Stuck on "Connecting…" / "Not ready" | 21116/UDP+TCP or 21117/TCP blocked; wrong host |
| Connected but black screen | Screen capture not started on the phone (see the hard limit above) |
| You can see but not control | **RustDesk Input** accessibility was switched off. OEM battery killers and some updates do this; re-enable it or run `make rustdesk-perms` |
| Works on Wi-Fi, fails on mobile data | Carrier NAT blocks hole punching; it should fall back to the relay (21117), so check that hbbr is running |
