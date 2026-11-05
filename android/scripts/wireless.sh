#!/usr/bin/env bash
# Wi-Fi adb helper. Phone and PC must be on the same network.
#
#   wireless.sh pair IP:PORT [CODE]  Android 11+: Developer options > Wireless debugging >
#                                    "Pair device with pairing code" (one-time per PC)
#   wireless.sh connect IP:PORT      Android 11+: IP:PORT shown on the Wireless debugging
#                                    screen itself (NOT the pairing port; changes often)
#   wireless.sh tcpip [PORT]         Any version: phone on USB now; switches adbd to TCP
#                                    (default 5555) and connects. Lost on phone reboot.
#   wireless.sh discover             List devices advertised over mDNS (Android 11+)
#   wireless.sh disconnect [IP:PORT] Drop one (or all) TCP connections
#   wireless.sh status               adb devices -l
#
# Then mirror with:  scrcpy -e   (or: make mirror-wifi)
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# Wi-Fi IPv4 of the single USB-attached device, from its routing table.
# Captured first: awk exits early, which would SIGPIPE the adb pipeline under pipefail.
usb_device_ip() {
  local routes
  routes=$(adb -d shell ip route 2>/dev/null | tr -d '\r') || true
  awk '/ dev wlan/ { for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' <<<"$routes"
}

cmd=${1:-help}
shift || true
case "$cmd" in help|-h|--help) ;; *)
  command -v adb >/dev/null || die "adb not found — run scripts/install.sh" ;;
esac

case "$cmd" in
  pair)
    addr=${1:?usage: wireless.sh pair IP:PORT [CODE]}
    code=${2:-}
    [[ -n $code ]] || read -rp "6-digit pairing code: " code
    [[ $code =~ ^[0-9]{6}$ ]] || die "the pairing code is 6 digits"
    # adb pair exits 0 even when pairing fails ("Failed: Wrong password…"), so check what it says.
    out=$(adb pair "$addr" "$code" 2>&1) || true
    echo "$out"
    [[ $out == *"Successfully paired"* ]] \
      || die "pairing failed: check the code and IP:PORT on the phone's 'Pair device with pairing code' dialog (both change every time it opens)"
    echo
    echo "Paired. Now connect using the IP:PORT on the main Wireless debugging screen:"
    echo "  $0 connect ${addr%:*}:<port>"
    ;;

  connect)
    addr=${1:?usage: wireless.sh connect IP:PORT}
    [[ $addr == *:* ]] || addr="$addr:5555"
    adb connect "$addr"
    adb devices -l
    ;;

  tcpip)
    port=${1:-5555}
    adb -d get-state >/dev/null 2>&1 \
      || die "need exactly one phone on USB, authorized (check 'adb devices')"
    ip=$(usb_device_ip)
    [[ -n $ip ]] || die "phone has no Wi-Fi IP (is Wi-Fi on?)"
    echo "==> phone Wi-Fi IP: $ip — restarting adbd on TCP port $port"
    adb -d tcpip "$port"
    # adbd restarts; give it a moment before connecting.
    ok=0
    for _ in 1 2 3 4 5; do
      sleep 1
      out=$(adb connect "$ip:$port" 2>&1) || true
      if [[ $out == *"connected to"* ]]; then ok=1; break; fi
    done
    adb devices -l
    (( ok )) || die "could not connect to $ip:$port over Wi-Fi ($out). KEEP THE CABLE IN: USB adb still works.
  Check that the PC and phone are on the same network (no guest/client-isolated Wi-Fi) and that no
  firewall blocks port $port, then retry: $0 connect $ip:$port"
    echo "You can unplug USB now. Mirror with: scrcpy -s $ip:$port"
    ;;

  discover)
    adb mdns check || true
    adb mdns services
    ;;

  disconnect)
    adb disconnect "$@"
    ;;

  status)
    adb devices -l
    ;;

  help|-h|--help)
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "unknown command '$cmd' (try: $0 help)"
    ;;
esac
