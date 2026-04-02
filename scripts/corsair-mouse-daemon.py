#!/usr/bin/env python3
"""
Corsair Darkstar Mouse Daemon

Grabs the Corsair Slipstream mouse and keyboard devices:
- Normalizes scroll events (hi-res accumulation + debounce)
- Remaps extra mouse buttons to keyboard shortcuts
"""

import argparse
import evdev
from evdev import UInput, ecodes, InputEvent
import select
import time
import sys

VENDOR_CORSAIR = 0x1B1C
PRODUCT_SLIPSTREAM = 0x1BDC
HIRES_PER_STEP = 120  # Standard: 120 hi-res units = 1 logical scroll step
DEBOUNCE_MS = 60  # Ignore direction reversals within this window
DIR_CONFIRM = 2   # Require N consecutive events in new direction before accepting
IDLE_RESET_MS = 2000  # Reset direction state after this idle period

# Button remapping: source key code -> action
# Action can be:
#   int              -> single key remap (e.g. ecodes.KEY_LEFTMETA)
#   [int, ...]       -> keyboard combo, modifiers first (e.g. [ecodes.KEY_LEFTCTRL, ecodes.KEY_C])
#   [[...], [...]]   -> macro: sequence of combos, each pressed+released in order (on button DOWN only)
#   None             -> block the button entirely
"""
Maus keys:
vorne oben 1
vorne unten 2
hinten oben 3
hinten unten 4
vorne dpi 5
hinten dpi 6
vorne profil 7
hinten profil 8
"""
BUTTON_MAP = {
    ecodes.KEY_2: ecodes.KEY_LEFTMETA,  # Vorne unten -> Super
    ecodes.KEY_5: [[ecodes.KEY_MUTE], [ecodes.KEY_LEFTMETA, ecodes.KEY_MUTE]],  # DPI vorne -> Mute, dann Super+Mute
    ecodes.KEY_6: [ecodes.KEY_LEFTMETA, ecodes.KEY_MUTE],    
}


def find_corsair_devices():
    """Find the Corsair mouse (REL_WHEEL) and keyboard (extra buttons) devices."""
    mouse = None
    keyboard = None
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if dev.info.vendor != VENDOR_CORSAIR or dev.info.product != PRODUCT_SLIPSTREAM:
            dev.close()
            continue
        caps = dev.capabilities()
        if ecodes.EV_REL in caps:
            rel_codes = [c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_REL]]
            if ecodes.REL_WHEEL in rel_codes:
                if mouse is None:
                    mouse = dev
                    continue
        if "Keyboard" in dev.name:
            if ecodes.EV_KEY in caps and ecodes.EV_LED in caps:
                if keyboard is None:
                    keyboard = dev
                    continue
        dev.close()
    return mouse, keyboard


def build_combined_caps(mouse, keyboard):
    """Build UInput capabilities combining mouse + keyboard + remap keys."""
    caps = mouse.capabilities()
    caps.pop(ecodes.EV_SYN, None)

    # Remove hi-res scroll
    if ecodes.EV_REL in caps:
        caps[ecodes.EV_REL] = [
            c for c in caps[ecodes.EV_REL]
            if (c[0] if isinstance(c, tuple) else c) not in
               (ecodes.REL_WHEEL_HI_RES, ecodes.REL_HWHEEL_HI_RES)
        ]

    # Merge keyboard EV_KEY capabilities
    existing_keys = set()
    if ecodes.EV_KEY in caps:
        existing_keys = {c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_KEY]}
    if keyboard:
        kb_caps = keyboard.capabilities()
        if ecodes.EV_KEY in kb_caps:
            for c in kb_caps[ecodes.EV_KEY]:
                code = c[0] if isinstance(c, tuple) else c
                existing_keys.add(code)

    # Add remap target keycodes
    for action in BUTTON_MAP.values():
        if action is None:
            continue
        if isinstance(action, int):
            existing_keys.add(action)
        elif isinstance(action, list) and action and isinstance(action[0], list):
            for combo in action:
                existing_keys.update(combo)
        elif isinstance(action, list):
            existing_keys.update(action)

    caps[ecodes.EV_KEY] = list(existing_keys)
    return caps


def resolve_event_name(code):
    """Resolve an EV_KEY event code to a human-readable name."""
    name = ecodes.BTN.get(code, ecodes.KEY.get(code, f"UNKNOWN_{code}"))
    if isinstance(name, (list, tuple)):
        return "/".join(name)
    return name


def discover_buttons(devices):
    """Discovery mode: print all button events so the user can identify codes."""
    for dev in devices:
        dev.grab()
    print("=== Button Discovery Mode ===", file=sys.stderr)
    print("Drücke Maustasten. Ctrl+C zum Beenden.", file=sys.stderr)
    print(f"{'Device':<12} {'Code':<10} {'Name':<30} {'State'}", file=sys.stderr)
    print("-" * 65, file=sys.stderr)
    state_names = {0: "UP", 1: "DOWN", 2: "REPEAT"}
    try:
        while True:
            r, _, _ = select.select(devices, [], [])
            for dev in r:
                for event in dev.read():
                    if event.type == ecodes.EV_KEY:
                        name = resolve_event_name(event.code)
                        state = state_names.get(event.value, str(event.value))
                        short = dev.path.split("/")[-1]
                        print(f"{short:<12} 0x{event.code:03X}    {name:<30} {state}",
                              file=sys.stderr)
    except KeyboardInterrupt:
        pass
    finally:
        for dev in devices:
            try:
                dev.ungrab()
            except OSError:
                pass


def handle_button_remap(event, ui, held_combo_keys):
    """Handle button remapping. Returns True if the event was consumed."""
    if event.type != ecodes.EV_KEY or event.code not in BUTTON_MAP:
        return False

    action = BUTTON_MAP[event.code]

    if action is None:
        return True

    # Single key remap
    if isinstance(action, int):
        ui.write_event(InputEvent(event.sec, event.usec,
                                  ecodes.EV_KEY, action, event.value))
        ui.syn()
        return True

    # Macro: sequence of combos, fire all on DOWN, ignore UP/REPEAT
    if isinstance(action, list) and action and isinstance(action[0], list):
        if event.value == 1:  # DOWN
            for combo in action:
                for key in combo:
                    ui.write_event(InputEvent(event.sec, event.usec,
                                              ecodes.EV_KEY, key, 1))
                ui.syn()
                for key in reversed(combo):
                    ui.write_event(InputEvent(event.sec, event.usec,
                                              ecodes.EV_KEY, key, 0))
                ui.syn()
        return True

    # Keyboard combo (modifiers first)
    if isinstance(action, list):
        if event.value == 1:  # DOWN
            for key in action:
                ui.write_event(InputEvent(event.sec, event.usec,
                                          ecodes.EV_KEY, key, 1))
                held_combo_keys.add(key)
            ui.syn()
        elif event.value == 0:  # UP
            for key in reversed(action):
                ui.write_event(InputEvent(event.sec, event.usec,
                                          ecodes.EV_KEY, key, 0))
                held_combo_keys.discard(key)
            ui.syn()
        return True

    return False


def main():
    parser = argparse.ArgumentParser(description="Corsair Darkstar Mouse Daemon")
    parser.add_argument("--discover", action="store_true",
                        help="Print all button events for discovery, then exit")
    parser.add_argument("--debug-scroll", action="store_true",
                        help="Log raw scroll events for debugging")
    args = parser.parse_args()

    mouse, keyboard = find_corsair_devices()
    if not mouse:
        print("Corsair Slipstream mouse not found, exiting.", file=sys.stderr)
        sys.exit(1)

    print(f"Found mouse: {mouse.name} at {mouse.path}", file=sys.stderr)
    if keyboard:
        print(f"Found keyboard: {keyboard.name} at {keyboard.path}", file=sys.stderr)
    else:
        print("Warning: Corsair keyboard device not found, extra buttons won't work.",
              file=sys.stderr)

    all_devices = [mouse] + ([keyboard] if keyboard else [])

    if args.discover:
        discover_buttons(all_devices)
        return

    caps = build_combined_caps(mouse, keyboard)
    ui = UInput(caps, name="CorsairFixed", vendor=VENDOR_CORSAIR, product=PRODUCT_SLIPSTREAM)

    for dev in all_devices:
        dev.grab()
    print("Grabbed devices, processing events.", file=sys.stderr)

    wheel_acc = 0
    hwheel_acc = 0
    last_wheel_dir = 0
    last_wheel_time = 0.0
    pending_dir = 0       # Direction we're trying to confirm
    pending_count = 0     # How many consecutive events in pending_dir
    pending_acc = 0       # Accumulated value while confirming
    held_combo_keys = set()

    try:
        while True:
            r, _, _ = select.select(all_devices, [], [])
            for dev in r:
                for event in dev.read():
                    # Button remapping
                    if handle_button_remap(event, ui, held_combo_keys):
                        continue

                    if event.type == ecodes.EV_REL:
                        if event.code == ecodes.REL_WHEEL:
                            continue
                        if event.code == ecodes.REL_HWHEEL:
                            continue
                        if event.code == ecodes.REL_WHEEL_HI_RES:
                            now = time.monotonic() * 1000
                            direction = 1 if event.value > 0 else -1
                            dt = now - last_wheel_time if last_wheel_time > 0 else 0
                            last_wheel_time = now

                            # Idle reset: after long pause, accept any direction
                            if dt > IDLE_RESET_MS:
                                if args.debug_scroll:
                                    print(f"[RESET]   idle {dt:.0f}ms, direction reset",
                                          file=sys.stderr)
                                last_wheel_dir = 0
                                wheel_acc = 0
                                pending_dir = 0
                                pending_count = 0
                                pending_acc = 0

                            # Same direction as confirmed: emit normally
                            if direction == last_wheel_dir or last_wheel_dir == 0:
                                last_wheel_dir = direction
                                # Cancel any pending direction change
                                if pending_dir != 0:
                                    if args.debug_scroll:
                                        print(f"[BOUNCE]  pending {pending_count}x "
                                              f"in {'UP' if pending_dir > 0 else 'DN'} "
                                              f"dropped, back to original dir",
                                              file=sys.stderr)
                                    pending_dir = 0
                                    pending_count = 0
                                    pending_acc = 0
                                wheel_acc += event.value
                                steps = wheel_acc // HIRES_PER_STEP
                                if steps != 0:
                                    wheel_acc -= steps * HIRES_PER_STEP
                                    if args.debug_scroll:
                                        print(f"[EMIT]    val={event.value:+5d} "
                                              f"dt={dt:.1f}ms acc={wheel_acc:+5d} "
                                              f"steps={steps:+d}",
                                              file=sys.stderr)
                                    ui.write_event(InputEvent(
                                        event.sec, event.usec,
                                        ecodes.EV_REL, ecodes.REL_WHEEL, steps
                                    ))
                                    ui.syn()
                                elif args.debug_scroll:
                                    print(f"[ACC]     val={event.value:+5d} "
                                          f"dt={dt:.1f}ms acc={wheel_acc:+5d}",
                                          file=sys.stderr)
                                continue

                            # Direction change: need confirmation
                            if pending_dir == direction:
                                # Another event in the pending direction
                                pending_count += 1
                                pending_acc += event.value
                            else:
                                # First event in new direction
                                pending_dir = direction
                                pending_count = 1
                                pending_acc = event.value

                            if args.debug_scroll:
                                print(f"[PEND]    val={event.value:+5d} "
                                      f"dt={dt:.1f}ms count={pending_count}/"
                                      f"{DIR_CONFIRM}",
                                      file=sys.stderr)

                            # Confirmed: accept new direction
                            if pending_count >= DIR_CONFIRM:
                                last_wheel_dir = direction
                                wheel_acc = pending_acc
                                steps = wheel_acc // HIRES_PER_STEP
                                if steps != 0:
                                    wheel_acc -= steps * HIRES_PER_STEP
                                    if args.debug_scroll:
                                        print(f"[CONFIRM] dir={'UP' if direction > 0 else 'DN'} "
                                              f"acc={wheel_acc:+5d} steps={steps:+d}",
                                              file=sys.stderr)
                                    ui.write_event(InputEvent(
                                        event.sec, event.usec,
                                        ecodes.EV_REL, ecodes.REL_WHEEL, steps
                                    ))
                                    ui.syn()
                                pending_dir = 0
                                pending_count = 0
                                pending_acc = 0
                            continue
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
        for key in held_combo_keys:
            try:
                ui.write_event(InputEvent(0, 0, ecodes.EV_KEY, key, 0))
            except OSError:
                pass
        try:
            ui.syn()
        except OSError:
            pass
        for dev in all_devices:
            try:
                dev.ungrab()
            except OSError:
                pass
        ui.close()


if __name__ == "__main__":
    main()
