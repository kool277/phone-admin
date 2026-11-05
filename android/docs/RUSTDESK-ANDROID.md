# RustDesk on Android: remote control through your own server

This sets up the RustDesk Android app so you can control the phone over the internet, from Ubuntu or from an iPhone. All traffic goes through **your** self-hosted server, **`rat.jami.uz`** (from the `rustdesk-core` project), not RustDesk's public servers. Every permission is granted by hand on the phone. Checked against **RustDesk 1.5.1**.

## Your server: rat.jami.uz

| Value | What to enter |
|---|---|
| ID Server | `rat.jami.uz` |
| Relay Server | `rat.jami.uz` |
| API Server | leave empty (only used by RustDesk Server Pro) |
| Key | the server's public key: one line of 44 characters, ending in `=` |

Read the key on the server, where hbbs keeps it in its data directory:

```bash
cat <hbbs-data-dir>/id_ed25519.pub        # e.g. ./data/id_ed25519.pub next to docker-compose.yml
docker exec hbbs cat /root/id_ed25519.pub # same file, if hbbs runs in Docker with ./data mounted at /root
```

The key is public by design: clients use it to check that they're talking to *your* server. Never copy `id_ed25519` (without `.pub`), which is the private half. Enter the **same** three values on every device: the Android phone, the Ubuntu PC and the iPhone.

The server must accept **TCP 21115–21117 and UDP 21116**. Ports 21118 and 21119 are only needed for the web client. If the server sits behind a home router, forward those ports to it.

### Dynamic IP: always use the hostname

The server's public IP can change, and DDNS keeps `rat.jami.uz` pointing at the current one. That only helps if nothing stores the IP itself:

- Enter `rat.jami.uz` in the ID Server and Relay Server fields on every device. Never enter the IP.
- If hbbs is started with a relay option (`hbbs -r …`), give it the hostname too. hbbs passes that value to clients as the relay address.
- Keep the DDNS record's TTL short (a few minutes). After an IP change, clients reconnect once the new address resolves; they need no reconfiguration.
- Check the name from outside: `dig +short rat.jami.uz` should print the server's current public IP.

## 1. Install the app

With the phone attached over adb (see [SCRCPY.md](SCRCPY.md)):

```bash
make rustdesk-android     # downloads the latest APK for the phone's CPU from GitHub and installs it
```

You can also install it from [GitHub releases](https://github.com/rustdesk/rustdesk/releases) or F-Droid. Package name: `com.carriez.flutter_hbb`.

## 2. Point it at your server (on the phone)

1. Open RustDesk → **Settings** tab → **ID/Relay Server**.
2. Fill in:
   - **ID Server:** `rat.jami.uz`
   - **Relay Server:** `rat.jami.uz` (if left empty, it uses the ID server host on port 21117)
   - **API Server:** leave empty (only used by RustDesk Server Pro)
   - **Key:** paste the public key (see [Your server](#your-server-ratjamiuz))
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

### Optional: do the battery exemption over adb

You can do the Ignore Battery Optimizations step from Ubuntu instead. The phone needs USB debugging on:

```bash
make rustdesk-perms
```

This runs `dumpsys deviceidle whitelist +com.carriez.flutter_hbb` and then tells you whether **Input Control** is on. It does not turn Input Control on. Accessibility access lets an app control the whole phone, so you grant it on the phone itself, through Android's own screen (step 3 above). Screen capture also has to be tapped on the phone.

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

## 6. Connect from an iPhone

The RustDesk iOS app can control the Android phone through `rat.jami.uz` too. Set the same ID Server, Relay Server and Key in the app, then connect to the phone's ID. Step-by-step instructions are in [ios/docs/RUSTDESK-IOS.md](../../ios/docs/RUSTDESK-IOS.md). The reverse doesn't work: an iPhone can't share its own screen through RustDesk.

## Encryption

RustDesk's built-in end-to-end encryption protects each session. This setup adds no crypto of its own.

- **Server identity:** every device has a key pair. hbbs signs each device's public key with the server key, and the connecting side checks that signature against the **Key** you entered. This is why the Key must be the same everywhere.
- **Session key:** the connecting side creates a fresh symmetric key for every connection and seals it to the peer's verified public key. The rest of the session is encrypted with it. The relay (hbbr) only forwards ciphertext.
- **Without the Key** (or with a wrong one), RustDesk can't verify the peer and runs the session on a non-secured path. The session window then shows it as not secured. Fix the Key before you rely on the connection.
- **Passwords:** the permanent password is the remaining line of defense, so make it long and unique. Turning on RustDesk's 2FA in the Android app's Settings adds a second factor for incoming sessions.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Key mismatch" / "Failed to secure connection" | Key differs between the phone, the PC and `id_ed25519.pub`; re-paste it everywhere |
| Stuck on "Connecting…" / "Not ready" | 21116/UDP+TCP or 21117/TCP blocked; wrong host; `dig +short rat.jami.uz` empty or stale (DDNS not updated) |
| Worked yesterday, "Not ready" today | Server IP changed: check DDNS, and that no device has the IP typed in instead of `rat.jami.uz` |
| Connected but black screen | Screen capture not started on the phone (see the hard limit above) |
| You can see but not control | **RustDesk Input** accessibility was switched off. OEM battery killers and some updates do this; turn it back on on the phone (step 3). `make rustdesk-perms` shows whether it's on |
| Works on Wi-Fi, fails on mobile data | Carrier NAT blocks hole punching; it should fall back to the relay (21117), so check that hbbr is running |
