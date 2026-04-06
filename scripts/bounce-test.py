#!/usr/bin/env python3
"""
Bounce Test for Corsair Slipstream mouse.

Reads raw HID reports from /dev/hidraw6 (the boot mouse interface) and
counts wheel events by direction. Used to determine whether the encoder
produces spurious direction reversals during single-direction scrolling.

Usage:
  sudo systemctl stop corsair-mouse-daemon
  sudo ./bounce-test.py
  # Follow prompts: scroll only DOWN, then only UP
  sudo systemctl start corsair-mouse-daemon
"""

import os
import sys
import time
import select
import struct

VENDOR = 0x1B1C
PRODUCT = 0x1BDC


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
        if b"\x09\x38" in rd:  # Wheel usage
            return f"/dev/{name}"
    return None


def collect(path, duration):
    """Read from hidraw and return list of (t_ms, wheel_value) for non-zero wheels."""
    events = []
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    deadline = time.monotonic() + duration
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            r, _, _ = select.select([fd], [], [], min(remaining, 0.1))
            if not r:
                continue
            try:
                data = os.read(fd, 4096)
            except (BlockingIOError, OSError):
                continue
            if len(data) >= 9:
                # offset 8 = wheel byte (signed)
                wheel = struct.unpack_from("b", data, 8)[0]
                if wheel != 0:
                    events.append((time.monotonic() * 1000, wheel))
    finally:
        os.close(fd)
    return events


def analyze(events, expected_dir, label):
    """Print summary of events relative to expected direction."""
    print(f"\n=== {label} ===")
    if not events:
        print("  No events captured.")
        return
    correct = [v for _, v in events if (v > 0) == (expected_dir > 0)]
    wrong   = [v for _, v in events if (v > 0) != (expected_dir > 0)]
    total = len(events)
    sum_correct = sum(correct)
    sum_wrong = sum(wrong)
    print(f"  Total events       : {total}")
    print(f"  Expected direction : {'+' if expected_dir > 0 else '-'}")
    print(f"  Events in expected : {len(correct)}  (sum {sum_correct:+d})")
    print(f"  Events REVERSED    : {len(wrong)}    (sum {sum_wrong:+d})")
    if total > 0:
        bounce_pct = 100.0 * len(wrong) / total
        print(f"  Bounce rate        : {bounce_pct:.1f}%")
    if wrong:
        print(f"\n  Reversal events (timing relative to nearest correct event):")
        # For each wrong event, find the dt to the previous correct event
        prev_correct_t = None
        prev_correct_v = None
        wrong_idx = 0
        for t, v in events:
            is_correct = (v > 0) == (expected_dir > 0)
            if is_correct:
                prev_correct_t = t
                prev_correct_v = v
            else:
                dt_str = f"{t - prev_correct_t:6.1f}ms after {prev_correct_v:+d}" if prev_correct_t else "(no prior)"
                print(f"    t={t:11.1f} val={v:+3d}  ({dt_str})")
                wrong_idx += 1
                if wrong_idx >= 30:
                    print(f"    ... ({len(wrong) - wrong_idx} more)")
                    break


def main():
    path = find_wheel_hidraw()
    if not path:
        print("ERROR: No Corsair hidraw with wheel found.", file=sys.stderr)
        sys.exit(1)
    print(f"Reading from {path}", file=sys.stderr)

    duration = 6.0

    print("\n>>> Test 1/2: Scroll DOWN only, as fast as you can <<<")
    print(f"    Recording {duration:.0f} seconds, starting in 2s...")
    time.sleep(2)
    print("    GO!")
    down_events = collect(path, duration)
    print("    STOP.")

    time.sleep(1.5)

    print("\n>>> Test 2/2: Scroll UP only, as fast as you can <<<")
    print(f"    Recording {duration:.0f} seconds, starting in 2s...")
    time.sleep(2)
    print("    GO!")
    up_events = collect(path, duration)
    print("    STOP.")

    print("\n========== ANALYSIS ==========")
    analyze(down_events, expected_dir=-1, label="DOWN test")
    analyze(up_events,   expected_dir=+1, label="UP test")

    # Verdict
    print("\n========== VERDICT ==========\n")
    down_wrong = sum(1 for _, v in down_events if v > 0)
    up_wrong   = sum(1 for _, v in up_events if v < 0)
    total_wrong = down_wrong + up_wrong
    total = len(down_events) + len(up_events)
    if total == 0:
        print("  Not enough events captured.")
    elif total_wrong == 0:
        print("  ZERO bounce. Encoder is clean. DIR_CONFIRM filter is unnecessary;")
        print("  you can set DIR_CONFIRM=1 (off) for snappier reversals.")
    elif total_wrong <= 2:
        print(f"  {total_wrong} stray reversal(s) out of {total}. Borderline.")
        print("  DIR_CONFIRM=2 is overkill; DIR_CONFIRM=1 (off) probably fine.")
    else:
        rate = 100.0 * total_wrong / total
        print(f"  {total_wrong} reversal events out of {total} ({rate:.1f}%).")
        print("  Encoder bounce is REAL. DIR_CONFIRM filter is justified.")


if __name__ == "__main__":
    main()
