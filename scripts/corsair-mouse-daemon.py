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

# Encoder bounce filter (Corsair Darkstar Wireless has a noisy encoder, esp.
# in DOWN direction - measured 28% bounce rate vs 4% UP). Geist-ticks appear
# 80-700ms after the real event, so we need a long idle window AND a spike
# hold to drop unconfirmed reversals.
DIR_CONFIRM = 2       # Require N consecutive events in new direction to confirm change
IDLE_RESET_MS = 1000  # Reset direction state after this idle period (ms)
SPIKE_HOLD_MS = 150   # Drop pending reversal if not confirmed within this window

# Scroll acceleration: compensate for encoder missing ticks at high speed
ACCEL_MAX = 3.0        # Maximum multiplier at top speed
ACCEL_WINDOW_MS = 100  # dt below this triggers acceleration (above = 1.0x)

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

    confirmed_dir = 0     # Last confirmed scroll direction (+1/-1)
    pending_count = 0     # Consecutive events in unconfirmed new direction
    pending_first_t = 0.0 # Timestamp of first event in pending reversal
    last_scroll_time = 0.0
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
                        # Block raw legacy scroll (we re-emit from HI_RES)
                        if event.code in (ecodes.REL_WHEEL, ecodes.REL_HWHEEL):
                            continue

                        if event.code == ecodes.REL_WHEEL_HI_RES:
                            now = time.monotonic() * 1000
                            value = event.value
                            direction = 1 if value > 0 else -1
                            dt = now - last_scroll_time if last_scroll_time > 0 else IDLE_RESET_MS + 1
                            last_scroll_time = now

                            # Spike-hold: drop a stale pending reversal that
                            # was never confirmed by a 2nd event in time.
                            if pending_count > 0 and (now - pending_first_t) > SPIKE_HOLD_MS:
                                if args.debug_scroll:
                                    print(f"[DROP]    stale pending after "
                                          f"{now - pending_first_t:.1f}ms",
                                          file=sys.stderr)
                                pending_count = 0

                            # Idle reset: after long pause, accept any direction
                            if dt > IDLE_RESET_MS:
                                confirmed_dir = 0
                                pending_count = 0

                            # Smooth acceleration: linear ramp from 1x to ACCEL_MAX
                            if dt < ACCEL_WINDOW_MS:
                                t = dt / ACCEL_WINDOW_MS  # 0.0 (fast) → 1.0 (slow)
                                accel = ACCEL_MAX - (ACCEL_MAX - 1) * t
                            else:
                                accel = 1.0
                            accel_value = int(value * accel)

                            if confirmed_dir == 0 or direction == confirmed_dir:
                                # Same direction or first event: forward immediately
                                confirmed_dir = direction
                                pending_count = 0
                                ui.write_event(InputEvent(
                                    event.sec, event.usec,
                                    ecodes.EV_REL, ecodes.REL_WHEEL_HI_RES, accel_value
                                ))
                                ui.write_event(InputEvent(
                                    event.sec, event.usec,
                                    ecodes.EV_REL, ecodes.REL_WHEEL,
                                    accel_value // HIRES_PER_STEP
                                ))
                                ui.syn()
                                if args.debug_scroll:
                                    print(f"[PASS]    val={value:+5d} accel={accel:.1f}x "
                                          f"out={accel_value:+5d} dt={dt:.1f}ms",
                                          file=sys.stderr)
                            else:
                                # Direction reversal: require confirmation
                                if pending_count == 0:
                                    pending_first_t = now
                                pending_count += 1
                                if pending_count >= DIR_CONFIRM:
                                    # Confirmed real direction change
                                    confirmed_dir = direction
                                    pending_count = 0
                                    ui.write_event(InputEvent(
                                        event.sec, event.usec,
                                        ecodes.EV_REL, ecodes.REL_WHEEL_HI_RES, value
                                    ))
                                    ui.write_event(InputEvent(
                                        event.sec, event.usec,
                                        ecodes.EV_REL, ecodes.REL_WHEEL,
                                        value // HIRES_PER_STEP
                                    ))
                                    ui.syn()
                                    if args.debug_scroll:
                                        print(f"[CONFIRM] val={value:+5d} dt={dt:.1f}ms "
                                              f"dir={'UP' if direction > 0 else 'DN'}",
                                              file=sys.stderr)
                                else:
                                    if args.debug_scroll:
                                        print(f"[HOLD]    val={value:+5d} dt={dt:.1f}ms "
                                              f"pending={pending_count}/{DIR_CONFIRM}",
                                              file=sys.stderr)
                            continue

                        if event.code == ecodes.REL_HWHEEL_HI_RES:
                            # Horizontal scroll: forward as-is (no bounce issues)
                            ui.write_event(event)
                            ui.write_event(InputEvent(
                                event.sec, event.usec,
                                ecodes.EV_REL, ecodes.REL_HWHEEL,
                                event.value // HIRES_PER_STEP
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
