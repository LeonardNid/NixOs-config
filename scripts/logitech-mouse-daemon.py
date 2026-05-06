#!/usr/bin/env python3
"""
Logitech G403 HERO Mouse Daemon

Grabs the G403 mouse and keyboard (extra buttons) devices and forwards
all events to a unified virtual device (LogitechFixed) for QEMU evdev passthrough.
"""

import sys
import select

import evdev
from evdev import UInput, ecodes, InputEvent

VENDOR_LOGITECH = 0x046D
PRODUCT_G403 = 0xC08F


def find_g403_devices():
    mouse = None
    keyboard = None
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        if dev.info.vendor != VENDOR_LOGITECH or dev.info.product != PRODUCT_G403:
            dev.close()
            continue
        caps = dev.capabilities()
        if ecodes.EV_REL in caps:
            rel_codes = [c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_REL]]
            if ecodes.REL_X in rel_codes and mouse is None:
                mouse = dev
                continue
        if ecodes.EV_KEY in caps and ecodes.EV_LED in caps and keyboard is None:
            keyboard = dev
            continue
        dev.close()
    return mouse, keyboard


def build_combined_caps(mouse, keyboard):
    caps = mouse.capabilities()
    caps.pop(ecodes.EV_SYN, None)

    existing_keys = set()
    if ecodes.EV_KEY in caps:
        existing_keys = {c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_KEY]}

    if keyboard:
        kb_caps = keyboard.capabilities()
        if ecodes.EV_KEY in kb_caps:
            for c in kb_caps[ecodes.EV_KEY]:
                existing_keys.add(c[0] if isinstance(c, tuple) else c)

    caps[ecodes.EV_KEY] = list(existing_keys)
    return caps


def main():
    mouse, keyboard = find_g403_devices()
    if not mouse:
        print("Logitech G403 HERO mouse not found, exiting.", file=sys.stderr)
        sys.exit(1)

    print(f"Found mouse: {mouse.name} at {mouse.path}", file=sys.stderr)
    if keyboard:
        print(f"Found keyboard: {keyboard.name} at {keyboard.path}", file=sys.stderr)

    all_devices = [mouse] + ([keyboard] if keyboard else [])

    caps = build_combined_caps(mouse, keyboard)
    ui = UInput(caps, name="LogitechFixed", vendor=VENDOR_LOGITECH, product=PRODUCT_G403)

    for dev in all_devices:
        dev.grab()
    print("Grabbed devices, processing events.", file=sys.stderr)

    try:
        while True:
            r, _, _ = select.select(all_devices, [], [])
            for dev in r:
                for event in dev.read():
                    ui.write_event(event)
                    if event.type == ecodes.EV_SYN:
                        ui.syn()
    except (KeyboardInterrupt, OSError):
        pass
    finally:
        for dev in all_devices:
            try:
                dev.ungrab()
            except OSError:
                pass
        ui.close()


if __name__ == "__main__":
    main()
