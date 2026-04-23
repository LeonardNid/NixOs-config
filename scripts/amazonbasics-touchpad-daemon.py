#!/usr/bin/env python3
"""
AmazonBasics Touchpad Hotspot Daemon.

Grabs the real AmazonBasics touchpad evdev exclusively and re-emits all
events through a virtual uinput touchpad, which libinput picks up like
the original. Single-finger taps that start inside a configured hotspot
rectangle are swallowed (no BTN_LEFT, no cursor move) and replaced by
a keyboard combo on a separate virtual keyboard device.

Current hotspot: top-left 20% x 20% -> Super+O (niri toggle-overview).

Runs as a systemd service, started once at boot. If the touchpad is not
present or disappears (unplug), the daemon idles and retries until it
comes back. No udev-triggered restart needed.
"""

import select
import sys
import time

import evdev
from evdev import UInput, ecodes as E

TOUCHPAD_NAME = "Telink amazonbasics_touchpad Touchpad"

# Touchpad axis ranges (verified via evtest; firmware-fixed).
X_MAX, Y_MAX = 1973, 1458

# Hotspot: top-left, 20% x 20% (~3 cm x 2.3 cm at 13 units/mm).
HOTSPOT_X = (0, int(X_MAX * 0.2))
HOTSPOT_Y = (0, int(Y_MAX * 0.2))

# Tap classifier. If the finger is up within TAP_MAX_MS and never moved
# farther than TAP_MAX_DIST from its start, it's a tap; otherwise it's a
# drag/hold and we forward the buffered events normally.
TAP_MAX_MS = 180
TAP_MAX_DIST = 30  # touchpad units, ~2.3 mm

HOTSPOT_KEYS = [E.KEY_LEFTMETA, E.KEY_O]

INPUT_PROPS = [E.INPUT_PROP_POINTER, E.INPUT_PROP_BUTTONPAD]

# How often to poll for the device when it's absent (unplugged).
DEVICE_POLL_SEC = 2.0


def log(msg):
    print(msg, file=sys.stderr, flush=True)


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
    return UInput(
        {E.EV_KEY: HOTSPOT_KEYS},
        name="AmazonBasics Touchpad Hotspot Keys",
        vendor=0x248A, product=0x8279,
    )


def run_once(touchpad):
    """Run the filter loop on an already-opened touchpad. Returns when the
    device disappears or on keyboard interrupt."""
    touchpad.grab()
    log(f"grabbed {touchpad.path} ({touchpad.name})")

    vpad = make_virtual_touchpad(touchpad)
    vkbd = make_virtual_keyboard()
    log(f"virtual pad: {vpad.device.path}")
    log(f"virtual kbd: {vkbd.device.path}")
    time.sleep(0.3)

    current_x = 0
    current_y = 0

    state_buffering = False
    buffer_pkts = []
    touch_start_time = 0.0
    start_x = 0
    start_y = 0
    max_dist = 0.0

    packet = []

    def emit_super_o():
        for k in HOTSPOT_KEYS:
            vkbd.write(E.EV_KEY, k, 1)
        vkbd.syn()
        for k in reversed(HOTSPOT_KEYS):
            vkbd.write(E.EV_KEY, k, 0)
        vkbd.syn()

    def flush_buffer():
        for pkt in buffer_pkts:
            for e in pkt:
                vpad.write_event(e)
        buffer_pkts.clear()

    def forward_packet(pkt):
        for e in pkt:
            vpad.write_event(e)

    try:
        while True:
            timeout = 0.05 if state_buffering else 1.0
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

                    session_start = False
                    session_end = False
                    multi_touch = False
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
                            elif e.code in (E.BTN_TOOL_DOUBLETAP,
                                            E.BTN_TOOL_TRIPLETAP,
                                            E.BTN_TOOL_QUADTAP,
                                            E.BTN_TOOL_QUINTTAP) and e.value == 1:
                                multi_touch = True

                    if session_start and not state_buffering:
                        if (HOTSPOT_X[0] <= current_x <= HOTSPOT_X[1]
                                and HOTSPOT_Y[0] <= current_y <= HOTSPOT_Y[1]):
                            state_buffering = True
                            touch_start_time = time.monotonic()
                            start_x = current_x
                            start_y = current_y
                            max_dist = 0.0

                    if state_buffering:
                        dx = current_x - start_x
                        dy = current_y - start_y
                        d = (dx * dx + dy * dy) ** 0.5
                        if d > max_dist:
                            max_dist = d

                        buffer_pkts.append(pkt)

                        dt_ms = (time.monotonic() - touch_start_time) * 1000
                        commit = None
                        if multi_touch:
                            commit = "flush"
                        elif session_end:
                            if dt_ms < TAP_MAX_MS and max_dist < TAP_MAX_DIST:
                                commit = "swallow"
                            else:
                                commit = "flush"
                        elif dt_ms > TAP_MAX_MS or max_dist > TAP_MAX_DIST:
                            commit = "flush"

                        if commit == "swallow":
                            buffer_pkts.clear()
                            state_buffering = False
                            emit_super_o()
                        elif commit == "flush":
                            flush_buffer()
                            state_buffering = False
                    else:
                        forward_packet(pkt)
            else:
                if state_buffering:
                    dt_ms = (time.monotonic() - touch_start_time) * 1000
                    if dt_ms > TAP_MAX_MS:
                        flush_buffer()
                        state_buffering = False
    finally:
        try: touchpad.ungrab()
        except OSError: pass
        try: touchpad.close()
        except Exception: pass
        try: vpad.close()
        except Exception: pass
        try: vkbd.close()
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
            # Small delay before re-scanning, in case the device is still
            # disappearing from sysfs.
            time.sleep(1.0)
    except KeyboardInterrupt:
        log("stopping")


if __name__ == "__main__":
    main()
