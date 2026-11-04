#!/usr/bin/env bash
# Start the AirPlay receiver (uxplay) so the iPhone can mirror its screen to this desktop.
# VIEW ONLY: AirPlay sends video/audio to the receiver and nothing back; you cannot tap or type on the phone.
#
#   scripts/mirror.sh                 # receiver named "ios-viewer", fixed ports (uxplay -p)
#   scripts/mirror.sh -fs             # extra arguments go straight to uxplay (see `uxplay -h`)
#   NAME="My Desk" scripts/mirror.sh  # name shown in the iPhone's Screen Mirroring list
#
# Then on the iPhone: Control Center → Screen Mirroring → pick the name. Same Wi-Fi/LAN as this PC.
set -euo pipefail

NAME=${NAME:-ios-viewer}

die() { echo "error: $*" >&2; exit 1; }

command -v uxplay >/dev/null || die "uxplay not installed: run scripts/install.sh"

if command -v systemctl >/dev/null && ! systemctl is-active --quiet avahi-daemon; then
  die "avahi-daemon is not running, so the iPhone can't discover uxplay: sudo systemctl enable --now avahi-daemon"
fi

[[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || echo "warning: no DISPLAY/WAYLAND_DISPLAY; uxplay needs a desktop session to show video" >&2

# `ufw status` needs root; the config file is world-readable.
if grep -qs '^ENABLED=yes' /etc/ufw/ufw.conf; then
  echo "note: ufw is active; open uxplay's ports once with scripts/install.sh --no-mirror --no-manage --ufw" >&2
fi

ips=$(hostname -I 2>/dev/null || true)
echo "AirPlay receiver \"$NAME\" on ${ips:-this host}. iPhone: Control Center → Screen Mirroring → $NAME"
echo "View only: input from this PC does not reach the iPhone. Ctrl+C to stop."

# -nh: don't append @hostname to the name.  -p: fixed legacy ports TCP 7000,7001,7100 / UDP 6000,6001,7011.
exec uxplay -n "$NAME" -nh -p "$@"
