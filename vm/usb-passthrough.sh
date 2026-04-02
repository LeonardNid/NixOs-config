#!/usr/bin/env bash
# Temporärer USB-Passthrough für Corsair Darkstar (Kabel) zur Windows VM

VENDOR="0x1b1c"
PRODUCT="0x1bb2"
VM="windows11"

DEVICE_XML="<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='${VENDOR}'/>
    <product id='${PRODUCT}'/>
  </source>
</hostdev>"

case "$1" in
  attach)
    echo "Reiche Corsair Darkstar (Kabel) an VM durch..."
    echo "$DEVICE_XML" | sudo virsh attach-device "$VM" /dev/stdin --live
    ;;
  detach)
    echo "Trenne Corsair Darkstar von VM..."
    echo "$DEVICE_XML" | sudo virsh detach-device "$VM" /dev/stdin --live
    ;;
  *)
    echo "Usage: $0 {attach|detach}"
    exit 1
    ;;
esac
