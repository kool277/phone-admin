# Virtual Android in Docker (redroid), mirrored with scrcpy

[redroid](https://github.com/remote-android/redroid-doc) runs Android as a Docker container that shares the host kernel. It needs **no KVM**, so it works when Ubuntu is itself a VM without nested virtualization, where the Android Emulator would crawl. You can use it to try out the scrcpy and adb workflows in this repo without a phone.

## One-time host setup (root)

Android needs the binder driver from the host kernel. Ubuntu's generic kernel ships it as a module:

```bash
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
# load it on every boot:
echo binder_linux | sudo tee /etc/modules-load.d/redroid.conf
echo 'options binder_linux devices="binder,hwbinder,vndbinder"' | sudo tee /etc/modprobe.d/redroid.conf
```

Your user must be in the `docker` group, and scrcpy/adb must be installed (`make install`).

## Use

```bash
make vm-up        # start redroid, connect adb to 127.0.0.1:5600, wait for boot
make vm-mirror    # scrcpy window with full mouse/keyboard control
make vm-down      # stop it (apps and data persist)
```

Every adb tool in this repo works on it once you set the serial: `ANDROID_SERIAL=127.0.0.1:5600 scripts/adb-cheatsheet.sh info`, or `make install-apk APK=app.apk SERIAL=127.0.0.1:5600`. Dragging an APK onto the scrcpy window also installs it.

Settings, all optional environment variables for `scripts/redroid.sh`:

| Variable | Default | Notes |
|---|---|---|
| `REDROID_IMAGE` | `redroid/redroid:14.0.0-latest` | Other tags: `15.0.0-latest`, `16.0.0-latest`, `*_64only-latest` |
| `REDROID_SIZE` / `REDROID_DPI` | `720x1280` / `320` | Larger sizes cost CPU, since rendering is in software |
| `REDROID_PORT` | `5600` | Bound to **127.0.0.1 only**, so adb isn't exposed to the network |
| `REDROID_DATA` | `~/.local/share/redroid/<tag>` | `/data` of the device; `scripts/redroid.sh wipe` resets it |

## Limits

- **Software rendering.** There's no GPU passthrough on this host (`redroid_gpu_mode=guest`), so animations and 3D are slow and use CPU.
- In a VM without a GPU, scrcpy logs `Could not create VA-API device` and decodes in software. That's expected and harmless.
- **x86_64 only.** Apps that ship only ARM native libraries won't install or will crash. There's no Play Store; install APKs yourself.
- **No audio, camera or telephony.** The script passes `--no-audio` to scrcpy.
- **`--privileged` container.** Android needs it to set up its own mounts. Treat apps you run inside as having broad access to the host.
