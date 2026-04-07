#!/usr/bin/env python3
"""
Double-Scroll Test for Corsair Slipstream mouse.

Logs every wheel event from BOTH:
  - /dev/hidraw6              (raw HID, what the mouse sends)
  - /dev/input/eventXX        (CorsairFixed, what the daemon emits)

with a unique sequential ID. The user scrolls once every ~1 second; whenever
a perceived double-scroll occurs, note the displayed ID.

The daemon must be RUNNING for this test (we log its output, not replace it).

Usage:
  sudo ./double-scroll-test.py
  # Scroll one tick at a time, ~1s apart. Whenever you feel a double-scroll
  # happen in the focused window, write down the ID printed at that moment.
  # Ctrl+C when done.
"""

import os
import sys
import time
import select
import struct
import threading

VENDOR = 0x1B1C
PRODUCT = 0x1BDC


# ---------- discovery ----------

def find_wheel_hidraw():
    base = "/sys/class/hidraw"
    for name in sorted(os.listdir(base), key=lambda s: int(s[6:])):
        uevent_path = f"{base}/{name}/device/uevent"
        if not os.path.isfile(uevent_path):
            continue
        with open(uevent_path) as f:
            data = f.read()
        if f"{VENDOR:08X}:{PRODUCT:08X}" not in data.upper():
            continue
        rd_path = f"{base}/{name}/device/report_descriptor"
        try:
            with open(rd_path, "rb") as f:
                rd = f.read()
        except OSError:
            continue
        if b"\x09\x38" in rd:  # Wheel usage in Generic Desktop
            return f"/dev/{name}"
    return None


def find_corsair_fixed():
    """Locate the CorsairFixed virtual device created by the daemon."""
    import evdev
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
        except OSError:
            continue
        if d.name == "CorsairFixed":
            return d
        d.close()
    return None


# ---------- shared state ----------

state_lock = threading.Lock()
event_id = 0
start_t = None
log_lines = []  # tuples (id, time, source, info)


def log(source, info):
    """Print and remember a log line. Returns the ID assigned."""
    global event_id, start_t
    with state_lock:
        if start_t is None:
            start_t = time.monotonic()
        event_id += 1
        eid = event_id
        rel_t = time.monotonic() - start_t
    line = f"[{eid:5d}]  t={rel_t:8.3f}s  {source:8s}  {info}"
    log_lines.append((eid, rel_t, source, info))
    print(line, flush=True)
    return eid


# ---------- hidraw thread ----------

class HidrawThread(threading.Thread):
    def __init__(self, path):
        super().__init__(daemon=True)
        self.path = path
        self.stop_flag = False

    def run(self):
        fd = os.open(self.path, os.O_RDONLY | os.O_NONBLOCK)
        try:
            while not self.stop_flag:
                r, _, _ = select.select([fd], [], [], 0.1)
                if not r:
                    continue
                try:
                    data = os.read(fd, 4096)
                except (BlockingIOError, OSError):
                    continue
                if len(data) < 9:
                    continue
                wheel = struct.unpack_from("b", data, 8)[0]
                if wheel != 0:
                    sign = "+" if wheel > 0 else ""
                    log("HIDRAW", f"wheel={sign}{wheel}  raw={data.hex()}")
        finally:
            os.close(fd)


# ---------- evdev thread (CorsairFixed output) ----------

class EvdevThread(threading.Thread):
    def __init__(self, dev):
        super().__init__(daemon=True)
        self.dev = dev
        self.stop_flag = False

    def run(self):
        import evdev
        from evdev import ecodes
        while not self.stop_flag:
            r, _, _ = select.select([self.dev.fd], [], [], 0.1)
            if not r:
                continue
            try:
                for ev in self.dev.read():
                    if ev.type != ecodes.EV_REL:
                        continue
                    if ev.code == ecodes.REL_WHEEL:
                        sign = "+" if ev.value > 0 else ""
                        log("DAEMON", f"REL_WHEEL={sign}{ev.value}")
                    elif ev.code == ecodes.REL_WHEEL_HI_RES:
                        sign = "+" if ev.value > 0 else ""
                        log("DAEMON", f"REL_WHEEL_HI_RES={sign}{ev.value}")
            except (BlockingIOError, OSError):
                continue


# ---------- main ----------

def main():
    hidraw = find_wheel_hidraw()
    if not hidraw:
        print("ERROR: Corsair wheel hidraw not found.", file=sys.stderr)
        sys.exit(1)
    print(f"Reading raw mouse: {hidraw}", file=sys.stderr)

    fixed = find_corsair_fixed()
    if not fixed:
        print("WARNING: CorsairFixed evdev not found. Is the daemon running?",
              file=sys.stderr)
        print("         Continuing with hidraw only.", file=sys.stderr)
    else:
        print(f"Reading daemon output: {fixed.path}", file=sys.stderr)

    print("\n>>> Scroll ONE tick at a time, ~1s apart. Note IDs of doubles. Ctrl+C when done. <<<\n",
          file=sys.stderr)
    print(f"{'ID':>7}  {'time':>10}  {'source':<8}  detail")
    print("-" * 70)

    hid_thread = HidrawThread(hidraw)
    hid_thread.start()

    ev_thread = None
    if fixed:
        ev_thread = EvdevThread(fixed)
        ev_thread.start()

    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping...", file=sys.stderr)

    hid_thread.stop_flag = True
    hid_thread.join(timeout=0.5)
    if ev_thread:
        ev_thread.stop_flag = True
        ev_thread.join(timeout=0.5)

    print("\n========== SUMMARY ==========")
    print(f"Total events: {len(log_lines)}")
    hid_n = sum(1 for _, _, s, _ in log_lines if s == "HIDRAW")
    daemon_wheel_n = sum(1 for _, _, s, i in log_lines if s == "DAEMON" and i.startswith("REL_WHEEL="))
    print(f"  HIDRAW wheel reports : {hid_n}")
    print(f"  DAEMON REL_WHEEL     : {daemon_wheel_n}")
    print()
    print("Now tell me which IDs felt like double-scrolls.")


if __name__ == "__main__":
    main()
