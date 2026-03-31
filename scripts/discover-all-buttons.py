#!/usr/bin/env python3
"""Discover all button events from all Corsair devices."""

import evdev
from evdev import ecodes
import select

devices = []
for path in evdev.list_devices():
    dev = evdev.InputDevice(path)
    if dev.info.vendor == 0x1B1C:
        devices.append(dev)
    else:
        dev.close()

print("=== Lausche auf ALLEN Corsair-Geraeten ===")
for d in devices:
    print(f"  {d.path}  {d.name}")
print()
print("Device      Code       Name                           State")
print("-" * 65)

state_names = {0: "UP", 1: "DOWN", 2: "REPEAT"}

try:
    while True:
        r, _, _ = select.select(devices, [], [])
        for dev in r:
            for event in dev.read():
                if event.type == ecodes.EV_KEY:
                    name = ecodes.BTN.get(event.code, ecodes.KEY.get(event.code, f"UNKNOWN_{event.code}"))
                    if isinstance(name, (list, tuple)):
                        name = "/".join(name)
                    state = state_names.get(event.value, str(event.value))
                    short = dev.path.split("/")[-1]
                    print(f"{short:<12} 0x{event.code:03X}    {name:<30} {state}")
except KeyboardInterrupt:
    pass
finally:
    for d in devices:
        d.close()
