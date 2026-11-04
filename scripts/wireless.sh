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
usb_device_ip() {
  adb -d shell ip route 2>/dev/null | tr -d '\r' \
    | awk '/ dev wlan/ { for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }'
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
    adb pair "$addr" "$code"
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
    for _ in 1 2 3 4 5; do
      sleep 1
      out=$(adb connect "$ip:$port" 2>&1) || true
      [[ $out == *"connected to"* ]] && break
    done
    adb devices -l
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
