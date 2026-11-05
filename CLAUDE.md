# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

phone-admin: Bash scripts, Makefiles and docs for the owner's own phones from Ubuntu. Two independent halves, each with its own `CLAUDE.md` that holds the detailed rules:

- `android/`: scrcpy, adb, redroid, and the RustDesk Android client. Android allows remote control.
- `ios/`: uxplay mirroring, libimobiledevice, and the RustDesk iOS client used as a controller. The iPhone itself is **view + manage only**: no input injection, no pairing/Developer Mode/signing bypass.

Shared rule: every phone-side permission (RSA prompt, Trust This Computer, screen capture, accessibility, Developer Mode) stays a manual step on the phone. Scripts automate only the PC side.

This repo was merged from android-admin and ios-viewer with history preserved (`git log --follow android/...`, `ios/...`).

## Commands

```bash
make help              # root targets
make lint              # shellcheck both halves (Docker fallback) — keep it clean
make doctor            # both halves' doctor commands
make android-<t>       # = make -C android <t>; variables like SERIAL= pass through
make ios-<t>           # = make -C ios <t>; UDID= etc. pass through
```

## Cross-cutting facts

- RustDesk server: `rat.jami.uz` (DDNS, dynamic IP). Docs use the hostname, never an IP, and never the key's value; they show how to read `id_ed25519.pub`. Both halves' RustDesk docs link each other with relative paths.
- The root forwards with `make -C android|ios <t> CALLER=<root dir>`. Don't call sub-scripts from the root with root-relative paths, except the guarded ones in `devices`.
- Both halves' Makefiles share one parameter convention: values come only from the make command line (`$(call arg,X)`, never a variable inherited from the shell), are shell-quoted with `$(call q,…)`/`$(call qarg,X)`, and targets that take or produce paths run as `$(RUN) <abs script>`, i.e. from `CALLER`, so relative paths and defaults resolve where the user ran make. Keep new targets in that form.
- Photo import on both sides must stay non-destructive: copy only new files, never delete or overwrite.
