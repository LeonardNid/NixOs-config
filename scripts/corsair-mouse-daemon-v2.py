#!/usr/bin/env python3
"""
Corsair Darkstar Mouse Daemon — v2

Changes vs v1:
- Simpler scroll bounce filter: "single-bounce absorber" instead of
  DIR_CONFIRM/SPIKE_HOLD. Same-direction events always pass through with no
  gating. The first opposite-direction event is BUFFERED (not silently
  dropped); if a second opposite arrives within PENDING_MAX_MS, BOTH are
  flushed, so real reversals don't lose their first tick. If no follow-up
  arrives, the lone event is dropped as a ghost.
- IDLE_RESET_MS reduced 1000 -> 350. The old 1000ms was based on a Linux-side
  measurement of "ghost ticks up to 700ms after real events", but a 2026-04-07
  Windows test shows the same mouse scrolls cleanly there — so the 700ms
  figure is not a trustworthy firmware property. Worst-case reversal latency
  is now bounded by IDLE_RESET_MS (~350ms) instead of 1000ms.
- Confirmed reversals no longer silently drop the first tick (v1 only emitted
  the second event of the confirming pair).

Everything else (device discovery, button remap, capability merging) is
identical to v1.
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

# Bounce filter: single-event absorber.
# A buffered reversal waits up to PENDING_MAX_MS for confirmation by a second
# same-direction event. Set just under typical user reversal cadence so real
# reversals are caught but isolated ghosts age out.
PENDING_MAX_MS = 180
# After this idle gap, the next event passes as a fresh "first" event in any
# direction. Must be > PENDING_MAX_MS but short enough that the user never
# feels stuck. 350ms is barely perceptible.
IDLE_RESET_MS = 350

# Scroll acceleration: compensate perceived stutter when scrolling fast in one
# direction. Only applied on the same-direction pass-through path.
ACCEL_MAX = 3.0
ACCEL_WINDOW_MS = 100

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
    ecodes.KEY_2: ecodes.KEY_LEFTMETA,                        # Vorne unten -> Super
    ecodes.KEY_3: [ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHT],    # Hinten oben -> Super+Right
    ecodes.KEY_4: [ecodes.KEY_LEFTMETA, ecodes.KEY_LEFT],     # Hinten unten -> Super+Left
    ecodes.KEY_5: [[ecodes.KEY_MUTE], [ecodes.KEY_MICMUTE]],  # DPI vorne -> Audio-Mute, dann Mic-Mute
    ecodes.KEY_6: ecodes.KEY_MICMUTE,                         # DPI hinten -> Mic-Mute
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

    existing_keys = set()
    if ecodes.EV_KEY in caps:
        existing_keys = {c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_KEY]}
    if keyboard:
        kb_caps = keyboard.capabilities()
        if ecodes.EV_KEY in kb_caps:
            for c in kb_caps[ecodes.EV_KEY]:
                code = c[0] if isinstance(c, tuple) else c
                existing_keys.add(code)

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
    name = ecodes.BTN.get(code, ecodes.KEY.get(code, f"UNKNOWN_{code}"))
    if isinstance(name, (list, tuple)):
        return "/".join(name)
    return name


def discover_buttons(devices):
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
    if event.type != ecodes.EV_KEY or event.code not in BUTTON_MAP:
        return False

    action = BUTTON_MAP[event.code]

    if action is None:
        return True

    if isinstance(action, int):
        ui.write_event(InputEvent(event.sec, event.usec,
                                  ecodes.EV_KEY, action, event.value))
        ui.syn()
        return True

    if isinstance(action, list) and action and isinstance(action[0], list):
        if event.value == 1:
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

    if isinstance(action, list):
        if event.value == 1:
            for key in action:
                ui.write_event(InputEvent(event.sec, event.usec,
                                          ecodes.EV_KEY, key, 1))
                held_combo_keys.add(key)
            ui.syn()
        elif event.value == 0:
            for key in reversed(action):
                ui.write_event(InputEvent(event.sec, event.usec,
                                          ecodes.EV_KEY, key, 0))
                held_combo_keys.discard(key)
            ui.syn()
        return True

    return False


def emit_wheel(ui, sec, usec, hires_value):
    """Emit a hi-res wheel event + synthesized legacy REL_WHEEL + SYN."""
    ui.write_event(InputEvent(sec, usec, ecodes.EV_REL,
                              ecodes.REL_WHEEL_HI_RES, hires_value))
    ui.write_event(InputEvent(sec, usec, ecodes.EV_REL,
                              ecodes.REL_WHEEL, hires_value // HIRES_PER_STEP))
    ui.syn()


def main():
    parser = argparse.ArgumentParser(description="Corsair Darkstar Mouse Daemon v2")
    parser.add_argument("--discover", action="store_true",
                        help="Print all button events for discovery, then exit")
    parser.add_argument("--debug-scroll", action="store_true",
                        help="Log scroll filter decisions")
    args = parser.parse_args()

    mouse, keyboard = find_corsair_devices()
    if not mouse:
        print("Corsair Slipstream mouse not found, creating dummy CorsairFixed...", file=sys.stderr)
        dummy_caps = {
            ecodes.EV_KEY: [ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE,
                            ecodes.BTN_SIDE, ecodes.BTN_EXTRA],
            ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y,
                            ecodes.REL_WHEEL, ecodes.REL_WHEEL_HI_RES,
                            ecodes.REL_HWHEEL, ecodes.REL_HWHEEL_HI_RES],
        }
        ui = UInput(dummy_caps, name="CorsairFixed", vendor=VENDOR_CORSAIR, product=PRODUCT_SLIPSTREAM)
        try:
            while True:
                time.sleep(3)
                m, _ = find_corsair_devices()
                if m:
                    m.close()
                    print("Corsair device appeared, restarting to grab it.", file=sys.stderr)
                    sys.exit(1)
        except (KeyboardInterrupt, OSError):
            pass
        finally:
            ui.close()
        return

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
    print("Grabbed devices, processing events (v2 filter).", file=sys.stderr)

    # Filter state
    confirmed_dir = 0      # last forwarded direction (+1/-1), 0 = cold/idle
    last_fwd_t = 0.0       # time of last forwarded wheel event (ms)
    pending = None         # (hires_value, sec, usec, t_ms) or None
    held_combo_keys = set()

    try:
        while True:
            r, _, _ = select.select(all_devices, [], [])
            for dev in r:
                for event in dev.read():
                    if handle_button_remap(event, ui, held_combo_keys):
                        continue

                    if event.type == ecodes.EV_REL:
                        # Block raw legacy wheel events; we re-emit from HI_RES.
                        if event.code in (ecodes.REL_WHEEL, ecodes.REL_HWHEEL):
                            continue

                        if event.code == ecodes.REL_WHEEL_HI_RES:
                            now = time.monotonic() * 1000
                            value = event.value
                            direction = 1 if value > 0 else -1

                            # 1) Expire stale pending reversal.
                            if pending is not None and (now - pending[3]) > PENDING_MAX_MS:
                                if args.debug_scroll:
                                    print(f"[DROP]    stale pending "
                                          f"age={now - pending[3]:.0f}ms",
                                          file=sys.stderr)
                                pending = None

                            # 2) Idle reset: long gap -> accept next event fresh.
                            if confirmed_dir != 0 and last_fwd_t > 0 \
                                    and (now - last_fwd_t) > IDLE_RESET_MS:
                                if args.debug_scroll:
                                    print(f"[IDLE]    reset after "
                                          f"{now - last_fwd_t:.0f}ms",
                                          file=sys.stderr)
                                confirmed_dir = 0
                                pending = None

                            dt = (now - last_fwd_t) if last_fwd_t > 0 else 9999.0

                            # 3) Cold start / post-idle: first event passes through.
                            if confirmed_dir == 0:
                                emit_wheel(ui, event.sec, event.usec, value)
                                confirmed_dir = direction
                                last_fwd_t = now
                                if args.debug_scroll:
                                    print(f"[FIRST]   val={value:+5d}",
                                          file=sys.stderr)
                                continue

                            # 4) Same direction as confirmed: forward immediately.
                            if direction == confirmed_dir:
                                if pending is not None:
                                    if args.debug_scroll:
                                        print(f"[BOUNCE]  drop pending "
                                              f"(back to confirmed dir)",
                                              file=sys.stderr)
                                    pending = None
                                # Acceleration only on the clean same-direction path.
                                if dt < ACCEL_WINDOW_MS:
                                    t = dt / ACCEL_WINDOW_MS
                                    accel = ACCEL_MAX - (ACCEL_MAX - 1) * t
                                else:
                                    accel = 1.0
                                out = int(value * accel)
                                emit_wheel(ui, event.sec, event.usec, out)
                                last_fwd_t = now
                                if args.debug_scroll:
                                    print(f"[PASS]    val={value:+5d} "
                                          f"accel={accel:.1f}x out={out:+5d} "
                                          f"dt={dt:.0f}ms",
                                          file=sys.stderr)
                                continue

                            # 5) Opposite direction.
                            if pending is None:
                                # First reversal event: buffer, don't emit yet.
                                pending = (value, event.sec, event.usec, now)
                                if args.debug_scroll:
                                    print(f"[BUFFER]  val={value:+5d} "
                                          f"dt={dt:.0f}ms",
                                          file=sys.stderr)
                            else:
                                # Second opposite event: confirmed reversal.
                                # Flush the buffered one, THEN the current one.
                                p_val, p_sec, p_usec, _ = pending
                                emit_wheel(ui, p_sec, p_usec, p_val)
                                emit_wheel(ui, event.sec, event.usec, value)
                                confirmed_dir = direction
                                last_fwd_t = now
                                pending = None
                                if args.debug_scroll:
                                    print(f"[CONFIRM] flush {p_val:+d} + {value:+d} "
                                          f"dir={'UP' if direction > 0 else 'DN'}",
                                          file=sys.stderr)
                            continue

                        if event.code == ecodes.REL_HWHEEL_HI_RES:
                            # Horizontal scroll: no bounce issues, forward as-is.
                            ui.write_event(event)
                            ui.write_event(InputEvent(
                                event.sec, event.usec,
                                ecodes.EV_REL, ecodes.REL_HWHEEL,
                                event.value // HIRES_PER_STEP
                            ))
                            ui.syn()
                            continue

                    # Pass all other events through unchanged.
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
