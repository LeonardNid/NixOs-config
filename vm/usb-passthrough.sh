#!/usr/bin/env bash
# Temporärer USB-Passthrough für Corsair Darkstar zur Windows VM.
#
# Die Maus zeigt sich als zwei separate USB-Devices:
#   - wired    : 0x1BB2  (Kabel direkt an der Maus)
#   - wireless : 0x1BDC  (Slipstream-Receiver/Dongle)
#
# Für iCUE-Wireless-Konfiguration (Polling-Rate, Scroll-Mode, on-board-Profile,
# Firmware-Flash im Wireless-Mode) MUSS der Dongle (wireless) durchgereicht
# werden, sonst "sieht" iCUE die Maus nicht als Corsair-USB-Gerät.
#
# WICHTIG: Der corsair-mouse-daemon grabbt die Maus per evdev. Der Kernel kann
# das USB-Device zwar trotzdem an VFIO geben, aber die VM sieht dann ein
# Device das im Host-Namespace noch angefasst wird. In der Praxis: Daemon vor
# attach stoppen, sonst kann iCUE eigenartige Zustände sehen. Das Skript
# prüft das automatisch.
#
# Nach Abschluss der iCUE-Arbeit: 'detach' + Daemon wieder starten.

set -eu

VM="windows11"
DAEMON="corsair-mouse-daemon"

VENDOR_WIRED="0x1b1c"
PRODUCT_WIRED="0x1bb2"

VENDOR_WIRELESS="0x1b1c"
PRODUCT_WIRELESS="0x1bdc"

device_xml() {
  local vendor=$1 product=$2
  cat <<EOF
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='${vendor}'/>
    <product id='${product}'/>
  </source>
</hostdev>
EOF
}

daemon_is_active() {
  systemctl is-active --quiet "$DAEMON"
}

check_daemon_before_attach() {
  if daemon_is_active; then
    echo "WARNUNG: '$DAEMON' läuft gerade."
    echo "Der Daemon grabbt die Maus und kann beim USB-Passthrough stören."
    echo "Bitte erst stoppen:"
    echo "  sudo systemctl stop $DAEMON"
    echo
    read -r -p "Jetzt automatisch stoppen? [y/N] " reply
    case "$reply" in
      y|Y|yes)
        sudo systemctl stop "$DAEMON"
        echo "Daemon gestoppt."
        ;;
      *)
        echo "Abgebrochen — starte das Skript neu, nachdem der Daemon gestoppt ist."
        exit 1
        ;;
    esac
  fi
}

do_attach() {
  local label=$1 vendor=$2 product=$3
  echo "Reiche Corsair Darkstar (${label}, ${vendor}:${product}) an VM '${VM}' durch..."
  if ! device_xml "$vendor" "$product" | sudo virsh attach-device "$VM" /dev/stdin --live; then
    echo "  -> ${label} nicht verfügbar (Device steckt nicht am Host)."
    return 1
  fi
}

# Find aliases of all hostdev entries in the live VM that match a given
# vendor/product. We detach by alias because detach-device with vendor/product
# XML alone doesn't reliably match when multiple entries exist.
find_aliases() {
  local vendor=$1 product=$2
  sudo virsh dumpxml "$VM" 2>/dev/null | \
    awk -v vendor="${vendor#0x}" -v product="${product#0x}" '
      /<hostdev / { inblock=1; buf=""; alias="" }
      inblock     { buf = buf "\n" $0 }
      /alias name=/ {
        match($0, /alias name=.([a-zA-Z0-9_]+)./, m)
        if (m[1] != "") alias = m[1]
      }
      /<\/hostdev>/ {
        if (tolower(buf) ~ tolower("vendor id=.0x" vendor ".") &&
            tolower(buf) ~ tolower("product id=.0x" product ".")) {
          print alias
        }
        inblock=0
      }
    '
}

do_detach() {
  local label=$1 vendor=$2 product=$3
  local aliases
  aliases=$(find_aliases "$vendor" "$product")
  if [[ -z "$aliases" ]]; then
    echo "Kein aktives hostdev für ${label} (${vendor}:${product}) gefunden — nichts zu tun."
    return 0
  fi
  echo "Trenne Corsair Darkstar (${label}, ${vendor}:${product}) von VM '${VM}'..."
  while IFS= read -r a; do
    [[ -z "$a" ]] && continue
    echo "  detach-device-alias $a"
    sudo virsh detach-device-alias "$VM" "$a" --live || true
  done <<< "$aliases"
}

usage() {
  cat <<EOF
Usage: $0 {attach|detach|status} [wired|wireless|both]

  wired     = 0x1BB2 (Kabel direkt)
  wireless  = 0x1BDC (Slipstream-Dongle)   <- für iCUE-Wireless-Setup
  both      = beide gleichzeitig
  (default) = wired

Beispiele:
  $0 attach wireless     # Dongle an VM durchreichen
  $0 detach wireless     # Dongle zurückholen
  $0 status              # Liste aller derzeit attachten Corsair-Devices
EOF
  exit 1
}

status() {
  echo "Aktive Corsair-USB-hostdev-Einträge in VM '$VM':"
  sudo virsh dumpxml "$VM" 2>/dev/null | \
    awk '/<hostdev / { inblock=1; buf="" }
         inblock     { buf = buf "\n" $0 }
         /<\/hostdev>/ { if (tolower(buf) ~ /1b1c/) print buf; inblock=0 }' | \
    grep -E "vendor id|product id|alias name|address bus" || echo "  (keine)"
}

action=${1:-}
target=${2:-wired}

case "$action" in
  attach)
    check_daemon_before_attach
    op=do_attach
    ;;
  detach)
    op=do_detach
    ;;
  status)
    status
    exit 0
    ;;
  *)
    usage
    ;;
esac

case "$target" in
  wired)
    $op wired "$VENDOR_WIRED" "$PRODUCT_WIRED"
    ;;
  wireless)
    $op wireless "$VENDOR_WIRELESS" "$PRODUCT_WIRELESS"
    ;;
  both)
    $op wired    "$VENDOR_WIRED"    "$PRODUCT_WIRED"    || true
    $op wireless "$VENDOR_WIRELESS" "$PRODUCT_WIRELESS" || true
    ;;
  *)
    usage
    ;;
esac

if [[ "$action" == "detach" ]]; then
  if ! daemon_is_active; then
    echo
    echo "Hinweis: '$DAEMON' ist nicht aktiv. Zum Wiederaktivieren:"
    echo "  sudo systemctl start $DAEMON"
  fi
fi
