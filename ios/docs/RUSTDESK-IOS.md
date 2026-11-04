# RustDesk on the iPhone: control your Android phone over the internet

The RustDesk iOS app turns the iPhone into a **remote control** for your other devices: the Android phone set up with [android-admin](https://github.com/kool277/android-admin), the Ubuntu PC, and anything else running RustDesk. All traffic goes through **your** server, **`rat.jami.uz`**, not RustDesk's public servers. Checked against **RustDesk 1.5.1**.

> **The iPhone can't share its own screen through RustDesk.** The iOS app only works in one direction: it connects *out* and controls other devices. In RustDesk 1.5.1 the screen-sharing page is built only for Android, and the iOS app has none of the pieces iOS would require for screen sharing. This project doesn't work around that. To *see* the iPhone's screen, use AirPlay mirroring to Ubuntu ([MIRROR.md](MIRROR.md)), which works only on the same network.

| From | To | Works? |
|---|---|---|
| iPhone (RustDesk app) | Android phone | **Yes:** view + control, over the internet |
| iPhone (RustDesk app) | Ubuntu PC / other computers | **Yes:** view + control |
| Ubuntu PC (RustDesk) | Android phone | **Yes:** see android-admin's [RUSTDESK-ANDROID.md](https://github.com/kool277/android-admin/blob/main/docs/RUSTDESK-ANDROID.md) |
| Anything | iPhone | **No.** View it on the LAN with uxplay; manage it over USB ([MANAGE.md](MANAGE.md)) |

## 1. Prepare the Android side first

The Android phone has to be reachable before the iPhone can connect to it. Follow android-admin's [RUSTDESK-ANDROID.md](https://github.com/kool277/android-admin/blob/main/docs/RUSTDESK-ANDROID.md): server settings, screen capture, the Input Control permission and a permanent password. Write down the phone's **ID**, shown on the app's *Share screen* tab.

## 2. Install the app on the iPhone

Install **RustDesk Remote Desktop** from the App Store. The publisher should be Purslane Ltd., the company behind RustDesk.

## 3. Point it at rat.jami.uz

1. Open RustDesk → **Settings** tab → **ID/Relay Server**.
2. Fill in:

   | Field | Value |
   |---|---|
   | ID Server | `rat.jami.uz` |
   | Relay Server | `rat.jami.uz` |
   | API Server | leave empty |
   | Key | the server's public key, the same one as on the Android phone and the PC |

3. Tap **OK**.

To read the key, run this on the server: `cat <hbbs-data-dir>/id_ed25519.pub`, or `docker exec hbbs cat /root/id_ed25519.pub` if hbbs runs in Docker. It's one 44-character line ending in `=`. The key is public by design. Never copy `id_ed25519` (without `.pub`); that's the private half.

**Always type the hostname, never an IP.** The server's IP changes, and DDNS keeps `rat.jami.uz` pointing at the current one. A typed IP breaks the next time the IP changes.

## 4. Connect to the Android phone

1. On the **Connect** tab, enter the Android phone's ID and tap **→**.
2. Enter the permanent password you set on the Android phone.
3. Tap the screen to tap on the phone. Use the on-screen keyboard button to type. The session menu has Android's **Back**, **Home** and **Apps** buttons, plus volume and power.

If you see the Android screen but can't control it, the Android side lost its **RustDesk Input** permission. If the screen is black, screen capture on the Android side stopped. Both have to be fixed on the Android phone; see the hard limit section in RUSTDESK-ANDROID.md.

## Encryption

RustDesk's built-in end-to-end encryption protects each session. This setup adds no crypto of its own.

- The server signs every device's public key. Before a session starts, the iPhone checks that signature against the **Key** you entered, so the Key must match on every device.
- For every connection, the iPhone creates a fresh session key and seals it to the Android phone's verified public key. The relay (hbbr) on `rat.jami.uz` only forwards ciphertext.
- With no Key, or the wrong one, RustDesk can't verify the other side and runs the session on a non-secured path, shown as not secured in the session. Fix the Key before relying on it.

## Troubleshooting

| Symptom | Check |
|---|---|
| "Not ready" / can't reach the ID server | `dig +short rat.jami.uz` should print the server's current IP. If it's empty, the DDNS record is broken. Server ports: TCP 21115–21117, UDP 21116 |
| Worked before, fails after the server's IP changed | DDNS updated? Check that no device has the old IP typed in instead of the hostname |
| "Key mismatch" / "Failed to secure connection" | The Key differs between the iPhone, the Android phone and `id_ed25519.pub`; re-paste it |
| "Remote desktop is offline" | The Android RustDesk service isn't running or is on a different server; open RustDesk on the Android phone |
| Works on Wi-Fi, fails on mobile data | Hole punching is blocked by the carrier; RustDesk should fall back to the relay (TCP 21117), so check that hbbr is running |
