#!/usr/bin/env python3
"""
AmazonBasics Touchpad Hotspot + Reading-Layer Daemon.

Grabs the real AmazonBasics touchpad evdev exclusively and re-emits all
events through a virtual uinput touchpad, which libinput picks up like
the original. The daemon implements two layers:

Default layer:
  Single-finger taps that start inside a configured hotspot rectangle are
  swallowed and replaced by a keyboard combo on a separate virtual keyboard.

Reading layer (toggled by a 4-finger tap):
  Every single-finger tap anywhere on the pad is swallowed and replaced by
  N mouse-wheel-down notches on a virtual wheel device, for comfortable
  reading. Two-finger scroll and cursor movement still work normally.

Runs as a systemd service, started once at boot. If the touchpad is not
present or disappears (unplug), the daemon idles and retries until it
comes back. No udev-triggered restart needed.
"""

import select
import subprocess
import sys
import time

import evdev
from evdev import UInput, ecodes as E

TOUCHPAD_NAME = "Telink amazonbasics_touchpad Touchpad"

# Touchpad axis ranges (verified via evtest; firmware-fixed).
X_MAX, Y_MAX = 1973, 1458

# Tap classifier: finger must lift within TAP_MAX_MS and never move more
# than TAP_MAX_DIST units (~2.3 mm) from the start position.
TAP_MAX_MS = 180
TAP_MAX_DIST = 30

# Reading layer: each single-finger tap emits this many wheel notches down.
READING_WHEEL_NOTCHES = 3

# Notification target (user session running Mako).
NOTIFY_USER = "leonardn"
NOTIFY_UID = 1000

# ---------------------------------------------------------------------------
# Hotspot configuration — add/remove entries here, nothing else needs to change.
#
# Each entry:
#   "x": (x_min, x_max)  — touchpad X range (0–1973, left→right)
#   "y": (y_min, y_max)  — touchpad Y range (0–1458, top→bottom)
#   "keys": [key, ...]   — keys pressed simultaneously on a tap
#
# Hotspots only fire in the default layer; in reading mode every tap scrolls.
# ---------------------------------------------------------------------------
HOTSPOTS = [
    {   # top-left 20% × 20% → Super+O (niri toggle-overview)
        "x": (0,                  int(X_MAX * 0.20)),
        "y": (0,                  int(Y_MAX * 0.20)),
        "keys": [E.KEY_LEFTALT, E.KEY_SPACE],
    },
    {   # top-right 20% × 20% → Alt+Space (app launcher)
        "x": (int(X_MAX * 0.80), X_MAX),
        "y": (0,                  int(Y_MAX * 0.20)),
        "keys": [E.KEY_LEFTMETA, E.KEY_O],
    },
    {   # bottom-middle-left 20% × 10% → Arrow left
        "x": (int(X_MAX * 0.80), int(X_MAX * 0.90)),
        "y": (int(Y_MAX * 0.90), Y_MAX),
        "keys": [E.KEY_LEFT],
    },
    {   # bottom-middle-right 20% × 10% → Arrow right
        "x": (int(X_MAX * 0.90), X_MAX),
        "y": (int(Y_MAX * 0.90), Y_MAX),
        "keys": [E.KEY_RIGHT],
    },
]
# ---------------------------------------------------------------------------

INPUT_PROPS = [E.INPUT_PROP_POINTER, E.INPUT_PROP_BUTTONPAD]
DEVICE_POLL_SEC = 2.0

# BTN_TOOL_* code → finger count.
TOOL_FINGER_COUNT = {
    E.BTN_TOOL_FINGER:    1,
    E.BTN_TOOL_DOUBLETAP: 2,
    E.BTN_TOOL_TRIPLETAP: 3,
    E.BTN_TOOL_QUADTAP:   4,
    E.BTN_TOOL_QUINTTAP:  5,
}


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def notify(title, body):
    try:
        subprocess.Popen(
            [
                "runuser", "-u", NOTIFY_USER, "--",
                "env", f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{NOTIFY_UID}/bus",
                "notify-send", "-t", "1500", title, body,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        log(f"notify failed: {e}")


def find_hotspot(x, y):
    """Return the first matching hotspot dict for (x, y), or None."""
    for h in HOTSPOTS:
        if h["x"][0] <= x <= h["x"][1] and h["y"][0] <= y <= h["y"][1]:
            return h
    return None


def find_touchpad():
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        if d.name == TOUCHPAD_NAME:
            return d
        d.close()
    return None


def wait_for_touchpad():
    warned = False
    while True:
        d = find_touchpad()
        if d is not None:
            return d
        if not warned:
            log(f"waiting for '{TOUCHPAD_NAME}' ...")
            warned = True
        time.sleep(DEVICE_POLL_SEC)


def make_virtual_touchpad(source):
    caps = source.capabilities()
    caps.pop(E.EV_SYN, None)
    return UInput(
        caps,
        name="AmazonBasics Touchpad (hotspot-filtered)",
        vendor=0x248A, product=0x8278, version=0x111,
        input_props=INPUT_PROPS,
    )


def make_virtual_keyboard():
    all_keys = set()
    for h in HOTSPOTS:
        all_keys.update(h["keys"])
    return UInput(
        {E.EV_KEY: list(all_keys)},
        name="AmazonBasics Touchpad Hotspot Keys",
        vendor=0x248A, product=0x8279,
    )


def make_virtual_wheel():
    return UInput(
        {
            E.EV_KEY: [E.BTN_LEFT],
            E.EV_REL: [E.REL_WHEEL, E.REL_HWHEEL],
        },
        name="AmazonBasics Touchpad Wheel",
        vendor=0x248A, product=0x827A,
    )


def run_once(touchpad):
    """Run the filter loop on an already-opened touchpad. Returns when the
    device disappears or on keyboard interrupt."""
    touchpad.grab()
    log(f"grabbed {touchpad.path} ({touchpad.name})")

    vpad = make_virtual_touchpad(touchpad)
    vkbd = make_virtual_keyboard()
    vwheel = make_virtual_wheel()
    log(f"virtual pad:   {vpad.device.path}")
    log(f"virtual kbd:   {vkbd.device.path}")
    log(f"virtual wheel: {vwheel.device.path}")
    time.sleep(0.3)

    # ---- persistent layer state (lives across touch sessions) ----
    reading_mode = False

    # ---- per-session state (reset on each session_start) ----
    current_x = 0
    current_y = 0

    session_active = False
    session_decided = False   # True once we commit to "flush" before session_end
    session_buffer = []       # list of packets buffered during this session
    session_start_time = 0.0
    session_start_x = 0
    session_start_y = 0
    session_max_dist = 0.0
    session_max_tool = 1      # highest finger count seen this session

    packet = []

    def emit_combo(keys):
        for k in keys:
            vkbd.write(E.EV_KEY, k, 1)
        vkbd.syn()
        for k in reversed(keys):
            vkbd.write(E.EV_KEY, k, 0)
        vkbd.syn()

    def emit_wheel(notches):
        vwheel.write(E.EV_REL, E.REL_WHEEL, notches)
        vwheel.syn()

    def flush_buffer():
        for pkt in session_buffer:
            for e in pkt:
                vpad.write_event(e)
        session_buffer.clear()

    def forward_packet(pkt):
        for e in pkt:
            vpad.write_event(e)

    try:
        while True:
            timeout = 0.05 if (session_active and not session_decided) else 1.0
            r, _, _ = select.select([touchpad.fd], [], [], timeout)

            if r:
                try:
                    events = list(touchpad.read())
                except OSError:
                    log("touchpad disappeared")
                    return
                for ev in events:
                    if not (ev.type == E.EV_SYN and ev.code == E.SYN_REPORT):
                        packet.append(ev)
                        continue

                    pkt = packet + [ev]
                    packet = []

                    # Parse packet for classification signals.
                    session_start = False
                    session_end = False
                    for e in pkt:
                        if e.type == E.EV_ABS:
                            if e.code == E.ABS_MT_POSITION_X:
                                current_x = e.value
                            elif e.code == E.ABS_MT_POSITION_Y:
                                current_y = e.value
                        elif e.type == E.EV_KEY:
                            if e.code == E.BTN_TOUCH:
                                if e.value == 1:
                                    session_start = True
                                else:
                                    session_end = True
                            elif e.code in TOOL_FINGER_COUNT and e.value == 1:
                                count = TOOL_FINGER_COUNT[e.code]
                                if session_active and count > session_max_tool:
                                    session_max_tool = count

                    if session_start and not session_active:
                        session_active = True
                        session_decided = False
                        session_buffer.clear()
                        session_start_time = time.monotonic()
                        session_start_x = current_x
                        session_start_y = current_y
                        session_max_dist = 0.0
                        session_max_tool = 1

                    if session_active:
                        # Update movement distance.
                        dx = current_x - session_start_x
                        dy = current_y - session_start_y
                        d = (dx * dx + dy * dy) ** 0.5
                        if d > session_max_dist:
                            session_max_dist = d

                        if not session_decided:
                            session_buffer.append(pkt)

                            dt_ms = (time.monotonic() - session_start_time) * 1000
                            is_tap = (
                                session_end
                                and dt_ms < TAP_MAX_MS
                                and session_max_dist < TAP_MAX_DIST
                            )

                            if is_tap:
                                if session_max_tool == 4:
                                    # 4-finger tap → toggle reading layer.
                                    session_buffer.clear()
                                    reading_mode = not reading_mode
                                    notify("Reading mode", "on" if reading_mode else "off")
                                    log(f"reading_mode={'on' if reading_mode else 'off'}")
                                elif session_max_tool == 1:
                                    if reading_mode:
                                        session_buffer.clear()
                                        emit_wheel(-READING_WHEEL_NOTCHES)
                                    else:
                                        hit = find_hotspot(session_start_x, session_start_y)
                                        if hit is not None:
                                            session_buffer.clear()
                                            emit_combo(hit["keys"])
                                        else:
                                            flush_buffer()
                                else:
                                    # 2/3/5-finger tap: no action, just forward.
                                    flush_buffer()
                                session_active = False
                                session_decided = False
                            elif session_end:
                                # Long press or drag that ended — forward everything.
                                flush_buffer()
                                session_active = False
                                session_decided = False
                            elif dt_ms > TAP_MAX_MS or session_max_dist > TAP_MAX_DIST:
                                # Definitely not a tap anymore — flush and live-forward.
                                flush_buffer()
                                session_decided = True
                        else:
                            # Already decided: forward live. Reset on session end.
                            forward_packet(pkt)
                            if session_end:
                                session_active = False
                                session_decided = False
                    else:
                        forward_packet(pkt)

            else:
                # Select timeout — check for stale buffering session.
                if session_active and not session_decided:
                    dt_ms = (time.monotonic() - session_start_time) * 1000
                    if dt_ms > TAP_MAX_MS:
                        flush_buffer()
                        session_decided = True

    finally:
        try: touchpad.ungrab()
        except OSError: pass
        try: touchpad.close()
        except Exception: pass
        try: vpad.close()
        except Exception: pass
        try: vkbd.close()
        except Exception: pass
        try: vwheel.close()
        except Exception: pass


def main():
    log("amazonbasics-touchpad-daemon starting")
    try:
        while True:
            touchpad = wait_for_touchpad()
            try:
                run_once(touchpad)
            except OSError as e:
                log(f"device error: {e}")
            time.sleep(1.0)
    except KeyboardInterrupt:
        log("stopping")


if __name__ == "__main__":
    main()
