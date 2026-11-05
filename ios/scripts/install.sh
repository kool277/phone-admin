#!/usr/bin/env bash
# Install the phone-admin iOS toolchain on Ubuntu (24.04 tested) from Ubuntu's own packages.
#
#   scripts/install.sh                   # mirroring + management
#   scripts/install.sh --no-mirror       # management only (libimobiledevice, ifuse)
#   scripts/install.sh --no-manage       # mirroring only (uxplay, GStreamer, Avahi)
#   scripts/install.sh --pymobiledevice3 # also pipx-install pymobiledevice3 (iOS 17+ screenshots)
#   scripts/install.sh --ufw             # also open uxplay's fixed ports in ufw (only if ufw is active)
#   scripts/install.sh --dry-run         # print the commands instead of running them
#
# Mirroring:  uxplay + GStreamer decoders + avahi-daemon (the iPhone finds uxplay over Bonjour/mDNS).
# Management: usbmuxd + libimobiledevice-utils + ideviceinstaller + ifuse (+ rsync for photo import).
# Nothing here pairs with or changes the iPhone: "Trust This Computer" is tapped by hand (docs/MANAGE.md).
set -euo pipefail

mirror=1 manage=1 pmd3=0 ufw=0 dry=0
for a in "$@"; do
  case $a in
    --no-mirror) mirror=0 ;;
    --no-manage) manage=0 ;;
    --pymobiledevice3) pmd3=1 ;;
    --ufw) ufw=1 ;;
    --dry-run) dry=1 ;;
    -h|--help) sed -n '2,/^[^#]/{/^#/s/^# \{0,1\}//p}' "$0"; exit 0 ;;
    *) echo "unknown option: $a (see --help)" >&2; exit 2 ;;
  esac
done

run() { if (( dry )); then echo "+ $*"; else "$@"; fi; }
SUDO=(); (( EUID == 0 )) || SUDO=(sudo)

command -v apt-get >/dev/null || { echo "error: needs apt (Ubuntu/Debian)" >&2; exit 1; }

pkgs=()
(( mirror )) && pkgs+=(uxplay avahi-daemon gstreamer1.0-plugins-base gstreamer1.0-plugins-good
                       gstreamer1.0-plugins-bad gstreamer1.0-libav)
(( manage )) && pkgs+=(usbmuxd libimobiledevice-utils ideviceinstaller ifuse rsync)
(( pmd3 ))   && pkgs+=(pipx)

if (( ${#pkgs[@]} )); then
  run "${SUDO[@]}" apt-get update
  run "${SUDO[@]}" apt-get install -y "${pkgs[@]}"
fi

if (( mirror )); then
  # uxplay advertises itself through Avahi; without it the iPhone's Screen Mirroring list stays empty.
  run "${SUDO[@]}" systemctl enable --now avahi-daemon
fi

if (( ufw )); then
  if command -v ufw >/dev/null && grep -qs '^ENABLED=yes' /etc/ufw/ufw.conf; then
    # Ports of `uxplay -p` (what scripts/mirror.sh uses), plus mDNS so the iPhone can discover it.
    run "${SUDO[@]}" ufw allow 7000:7001/tcp comment 'uxplay'
    run "${SUDO[@]}" ufw allow 7100/tcp comment 'uxplay'
    run "${SUDO[@]}" ufw allow 6000:6001/udp comment 'uxplay'
    run "${SUDO[@]}" ufw allow 7011/udp comment 'uxplay'
    run "${SUDO[@]}" ufw allow 5353/udp comment 'mDNS'
  else
    echo "ufw is not active; no firewall change needed."
  fi
fi

if (( pmd3 )); then
  # User-level install (no sudo). Re-running this upgrades it, which new iOS versions often need.
  # (`pipx install` of an installed package exits 0 without upgrading, so pick the command.)
  if [[ $(pipx list --short 2>/dev/null || true) == *pymobiledevice3* ]]; then
    run pipx upgrade pymobiledevice3
  else
    run pipx install pymobiledevice3
  fi
  run pipx ensurepath
fi

cat <<'EOF'

Done. Next:
  make doctor     # check tools, usbmuxd, Avahi, the connected iPhone
  make pair       # USB cable + unlocked iPhone → tap "Trust" and enter the passcode on the phone
  make mirror     # then iPhone: Control Center → Screen Mirroring → phone-admin
EOF
(( pmd3 )) && echo "  (open a new terminal so pipx's ~/.local/bin is on PATH)"
exit 0
