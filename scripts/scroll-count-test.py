#!/usr/bin/env python3
"""
Scroll Count Test for Corsair mouse.

Logs every wheel event live with a running counter, so the user can scroll
at a controlled pace and compare felt-vs-measured.

Usage:
  sudo systemctl stop corsair-mouse-daemon
  sudo ./scroll-count-test.py
  # Scroll as requested. Ctrl+C to end. Final summary shows totals.
  sudo systemctl start corsair-mouse-daemon
"""

import os
import sys
import time
import select
import struct

VENDOR = 0x1B1C


def find_wheel_hidraw():
    base = "/sys/class/hidraw"
    candidates = []
    for name in sorted(os.listdir(base), key=lambda s: int(s[6:])):
        uevent_path = f"{base}/{name}/device/uevent"
        if not os.path.isfile(uevent_path):
            continue
        with open(uevent_path) as f:
            data = f.read()
        if f"{VENDOR:08X}:" not in data.upper():
            continue
        rd_path = f"{base}/{name}/device/report_descriptor"
        try:
            with open(rd_path, "rb") as f:
                rd = f.read()
        except OSError:
            continue
        if b"\x09\x38" in rd:
            product = None
            for line in data.splitlines():
                if line.startswith("HID_ID="):
                    parts = line.split(":")
                    if len(parts) >= 3:
                        product = parts[2].strip().upper()
            candidates.append((f"/dev/{name}", product))
    if not candidates:
        return None
    if len(candidates) > 1:
        print(f"Multiple wheel hidraws: {candidates}", file=sys.stderr)
        print(f"Using first: {candidates[0][0]}", file=sys.stderr)
    return candidates[0][0]


def main():
    path = find_wheel_hidraw()
    if not path:
        print("ERROR: No Corsair hidraw with wheel found.", file=sys.stderr)
        sys.exit(1)
    print(f"Reading from {path}\n", file=sys.stderr)
    print(">>> Scroll at controlled speed. Watch the counter grow per click. <<<")
    print(">>> Ctrl+C when done. <<<\n")

    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    count = 0
    tick_sum = 0
    tick_abs_sum = 0
    start = None
    last_t = None
    try:
        while True:
            r, _, _ = select.select([fd], [], [], 0.5)
            if not r:
                continue
            try:
                data = os.read(fd, 4096)
            except (BlockingIOError, OSError):
                continue
            if len(data) < 9:
                continue
            wheel = struct.unpack_from("b", data, 8)[0]
            if wheel == 0:
                continue
            now = time.monotonic()
            if start is None:
                start = now
            dt_ms = (now - last_t) * 1000 if last_t else 0
            last_t = now
            count += 1
            tick_sum += wheel
            tick_abs_sum += abs(wheel)
            sign = "+" if wheel > 0 else ""
            print(f"event #{count:4d}  wheel={sign}{wheel:+d}  dt={dt_ms:6.1f}ms  "
                  f"running_sum={tick_sum:+d}", flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        os.close(fd)
    if start and last_t:
        duration = last_t - start
        rate = count / duration if duration > 0 else 0
        print(f"\n========== SUMMARY ==========")
        print(f"Events (HID reports): {count}")
        print(f"Total ticks (sum of |wheel|): {tick_abs_sum}")
        print(f"Net direction sum:    {tick_sum:+d}")
        print(f"Duration:             {duration:.2f}s")
        print(f"Event rate:           {rate:.1f} events/s")
        print(f"Tick rate:            {tick_abs_sum/duration:.1f} ticks/s"
              if duration > 0 else "")


if __name__ == "__main__":
    main()
