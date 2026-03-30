#!/usr/bin/env python3
"""
Corsair Darkstar Scroll Wheel Fix

Grabs the Corsair Slipstream mouse and normalizes scroll events:
- Uses REL_WHEEL_HI_RES as primary scroll source (accumulates to 120 = 1 step)
- Blocks raw REL_WHEEL to prevent double-counting
- Debounces brief scroll direction reversals (encoder bounce)
"""

import evdev
from evdev import UInput, ecodes, InputEvent
import time
import sys

VENDOR_CORSAIR = 0x1B1C
PRODUCT_SLIPSTREAM = 0x1BDC
HIRES_PER_STEP = 120  # Standard: 120 hi-res units = 1 logical scroll step
DEBOUNCE_MS = 30  # Ignore direction reversals within this window


def find_corsair_mouse():
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if dev.info.vendor == VENDOR_CORSAIR and dev.info.product == PRODUCT_SLIPSTREAM:
            caps = dev.capabilities()
            if ecodes.EV_REL in caps:
                rel_codes = [c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_REL]]
                if ecodes.REL_WHEEL in rel_codes:
                    return dev
        dev.close()
    return None


def build_virtual_caps(mouse):
    caps = mouse.capabilities()
    caps.pop(ecodes.EV_SYN, None)
    # Remove hi-res scroll from virtual device capabilities
    if ecodes.EV_REL in caps:
        caps[ecodes.EV_REL] = [
            c for c in caps[ecodes.EV_REL]
            if (c[0] if isinstance(c, tuple) else c) not in
               (ecodes.REL_WHEEL_HI_RES, ecodes.REL_HWHEEL_HI_RES)
        ]
    return caps


def main():
    mouse = find_corsair_mouse()
    if not mouse:
        print("Corsair Slipstream mouse not found, exiting.", file=sys.stderr)
        sys.exit(1)

    print(f"Found: {mouse.name} at {mouse.path}", file=sys.stderr)

    caps = build_virtual_caps(mouse)
    ui = UInput(caps, name="CorsairFixed", vendor=VENDOR_CORSAIR, product=PRODUCT_SLIPSTREAM)

    mouse.grab()
    print("Grabbed mouse, normalizing scroll events.", file=sys.stderr)

    wheel_acc = 0
    hwheel_acc = 0
    last_wheel_dir = 0
    last_wheel_time = 0.0

    try:
        for event in mouse.read_loop():
            if event.type == ecodes.EV_REL:
                # Block raw REL_WHEEL — we reconstruct it from hi-res
                if event.code == ecodes.REL_WHEEL:
                    continue

                # Block raw REL_HWHEEL
                if event.code == ecodes.REL_HWHEEL:
                    continue

                # Process hi-res vertical scroll
                if event.code == ecodes.REL_WHEEL_HI_RES:
                    now = time.monotonic() * 1000
                    direction = 1 if event.value > 0 else -1

                    # Debounce: ignore brief direction reversals
                    if direction != last_wheel_dir and last_wheel_dir != 0:
                        if (now - last_wheel_time) < DEBOUNCE_MS:
                            continue
                        # Genuine direction change — reset accumulator
                        wheel_acc = 0

                    last_wheel_dir = direction
                    last_wheel_time = now

                    wheel_acc += event.value

                    # Emit scroll step(s) when accumulator reaches threshold
                    steps = wheel_acc // HIRES_PER_STEP
                    if steps != 0:
                        wheel_acc -= steps * HIRES_PER_STEP
                        ui.write_event(InputEvent(
                            event.sec, event.usec,
                            ecodes.EV_REL, ecodes.REL_WHEEL, steps
                        ))
                        ui.syn()
                    continue

                # Process hi-res horizontal scroll
                if event.code == ecodes.REL_HWHEEL_HI_RES:
                    hwheel_acc += event.value
                    steps = hwheel_acc // HIRES_PER_STEP
                    if steps != 0:
                        hwheel_acc -= steps * HIRES_PER_STEP
                        ui.write_event(InputEvent(
                            event.sec, event.usec,
                            ecodes.EV_REL, ecodes.REL_HWHEEL, steps
                        ))
                        ui.syn()
                    continue

            # Pass all other events through unchanged
            ui.write_event(event)
            if event.type == ecodes.EV_SYN:
                ui.syn()

    except (KeyboardInterrupt, OSError):
        pass
    finally:
        try:
            mouse.ungrab()
        except OSError:
            pass
        ui.close()


if __name__ == "__main__":
    main()
