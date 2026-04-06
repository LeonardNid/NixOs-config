#!/usr/bin/env python3
"""
Scroll Diagnostic for Corsair Slipstream mouse.

Reads:
  - All Corsair hidraw devices in parallel (raw HID reports from receiver)
  - The Corsair evdev device with REL_WHEEL (post kernel HID parsing)

Goal: Determine where wheel ticks vanish during fast scrolling.
  - If hidraw shows N ticks but evdev shows < N -> Linux input layer issue
  - If hidraw also shows < expected ticks -> mouse/firmware/RF issue (cannot fix in SW)

Usage:
  sudo systemctl stop corsair-mouse-daemon
  sudo ./scroll-diag.py
  # Scroll wheel as fast as you can for ~5 seconds, then Ctrl+C
  sudo systemctl start corsair-mouse-daemon
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

def find_corsair_hidraws():
    """Return list of dicts: {path, iface, has_wheel, rd_len}."""
    import re
    out = []
    base = "/sys/class/hidraw"
    if not os.path.isdir(base):
        return out
    for name in sorted(os.listdir(base), key=lambda s: int(s[6:])):
        uevent = f"{base}/{name}/device/uevent"
        if not os.path.isfile(uevent):
            continue
        with open(uevent) as f:
            data = f.read()
        if f"{VENDOR:08X}:{PRODUCT:08X}" not in data.upper():
            continue
        rd_path = f"{base}/{name}/device/report_descriptor"
        try:
            with open(rd_path, "rb") as f:
                rd = f.read()
        except OSError:
            rd = b""
        # Wheel usage = 0x09 0x38 inside Generic Desktop page
        has_wheel = b"\x09\x38" in rd
        # iface number = the .N suffix at the end of the USB interface dir
        # e.g. .../usb1/1-8/1-8:1.0/0003:1B1C:1BDC.003D
        link = os.readlink(f"{base}/{name}/device")
        m = re.search(r"/\d+-[\d.]+:\d+\.(\d+)/", link)
        iface = int(m.group(1)) if m else -1
        out.append({
            "path": f"/dev/{name}",
            "iface": iface,
            "has_wheel": has_wheel,
            "rd_len": len(rd),
        })
    return out


# ---------- hidraw logger ----------

class HidrawLogger(threading.Thread):
    def __init__(self, path, iface, has_wheel):
        super().__init__(daemon=True)
        self.path = path
        self.iface = iface
        self.has_wheel = has_wheel
        self.stop_flag = False
        self.events = []   # list of (t_ms, raw_bytes)
        self.error = None

    def run(self):
        try:
            fd = os.open(self.path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError as e:
            self.error = str(e)
            return
        try:
            while not self.stop_flag:
                r, _, _ = select.select([fd], [], [], 0.1)
                if not r:
                    continue
                try:
                    data = os.read(fd, 4096)
                except (BlockingIOError, OSError):
                    continue
                if data:
                    t = time.monotonic() * 1000
                    self.events.append((t, data))
        finally:
            try:
                os.close(fd)
            except OSError:
                pass


# ---------- evdev logger ----------

class EvdevLogger(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True)
        self.stop_flag = False
        self.events = []   # (t_ms, code_name, value)
        self.dev = None
        self.error = None

    def run(self):
        try:
            import evdev
            from evdev import ecodes
        except ImportError as e:
            self.error = f"evdev import failed: {e}"
            return
        for path in evdev.list_devices():
            try:
                d = evdev.InputDevice(path)
            except OSError:
                continue
            if d.info.vendor != VENDOR or d.info.product != PRODUCT:
                d.close()
                continue
            caps = d.capabilities()
            if ecodes.EV_REL in caps:
                rel_codes = [c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_REL]]
                if ecodes.REL_WHEEL in rel_codes:
                    self.dev = d
                    break
            d.close()
        if not self.dev:
            self.error = "no Corsair mouse with REL_WHEEL found in evdev"
            return
        while not self.stop_flag:
            r, _, _ = select.select([self.dev.fd], [], [], 0.1)
            if not r:
                continue
            try:
                for ev in self.dev.read():
                    if ev.type != ecodes.EV_REL:
                        continue
                    if ev.code in (ecodes.REL_WHEEL, ecodes.REL_WHEEL_HI_RES):
                        t = time.monotonic() * 1000
                        name = "WHEEL" if ev.code == ecodes.REL_WHEEL else "HIRES"
                        self.events.append((t, name, ev.value))
            except (BlockingIOError, OSError):
                continue
        try:
            self.dev.close()
        except OSError:
            pass


# ---------- report parsing ----------

def parse_boot_mouse_report(data):
    """Parse the iface=0 composite mouse HID report.

    Descriptor (no Report ID):
      - 32 bits buttons   (4 bytes)
      - 16-bit X, 16-bit Y (4 bytes)
      - 8-bit Wheel       (1 byte signed)
      - 8-bit AC Pan      (1 byte signed)
      - 5 bytes vendor
    Total: 15 bytes
    """
    if len(data) < 11:
        return None
    buttons = struct.unpack_from("<I", data, 0)[0]
    x = struct.unpack_from("<h", data, 4)[0]
    y = struct.unpack_from("<h", data, 6)[0]
    wheel = struct.unpack_from("b", data, 8)[0]
    pan = struct.unpack_from("b", data, 9)[0]
    return {"buttons": buttons, "x": x, "y": y, "wheel": wheel, "pan": pan}


def find_wheel_byte(data):
    """Heuristic: scan all byte offsets and return the offset most likely
    to be the wheel field. Wheel events should be small signed ints (-5..5
    typically), and zero in most reports. Returns None if not found."""
    candidates = []
    for off in range(min(len(data), 32)):
        sval = struct.unpack_from("b", data, off)[0]
        if sval != 0 and -8 <= sval <= 8:
            candidates.append((off, sval))
    return candidates


# ---------- main ----------

def main():
    hidraws = find_corsair_hidraws()
    if not hidraws:
        print("ERROR: No Corsair hidraws found.", file=sys.stderr)
        print("       Make sure the mouse is connected and awake.", file=sys.stderr)
        sys.exit(1)

    print("Corsair hidraws:", file=sys.stderr)
    for h in hidraws:
        marker = "  <-- has wheel" if h["has_wheel"] else ""
        print(f"  {h['path']}  iface={h['iface']}  rd={h['rd_len']}b{marker}",
              file=sys.stderr)

    # Start one logger per hidraw (skip iface 5 = boot keyboard, no relevance)
    loggers = []
    for h in hidraws:
        if h["iface"] == 5:
            continue
        l = HidrawLogger(h["path"], h["iface"], h["has_wheel"])
        loggers.append(l)
        l.start()

    ev_logger = EvdevLogger()
    ev_logger.start()

    time.sleep(0.3)
    print("\n>>> Scroll your wheel as fast as you can. Ctrl+C to stop. <<<\n",
          file=sys.stderr)
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping...\n", file=sys.stderr)

    for l in loggers:
        l.stop_flag = True
    ev_logger.stop_flag = True
    for l in loggers:
        l.join(timeout=0.5)
    ev_logger.join(timeout=0.5)

    print("========== RESULTS ==========\n")

    if ev_logger.error:
        print(f"  evdev: ERROR: {ev_logger.error}\n")

    # Per-hidraw summary
    wheel_iface_logger = None
    for l in loggers:
        if l.error:
            print(f"  {l.path}: ERROR: {l.error}\n")
            continue
        report_lengths = {}
        for _, data in l.events:
            report_lengths[len(data)] = report_lengths.get(len(data), 0) + 1
        print(f"  {l.path} (iface={l.iface}, has_wheel_in_descriptor={l.has_wheel})")
        print(f"    raw reports total : {len(l.events)}")
        print(f"    report lengths    : {dict(sorted(report_lengths.items()))}")
        if l.has_wheel:
            wheel_iface_logger = l
        print()

    # evdev summary
    wheel_evs = [(t, v) for t, n, v in ev_logger.events if n == "WHEEL"]
    hires_evs = [(t, v) for t, n, v in ev_logger.events if n == "HIRES"]
    print(f"  evdev")
    print(f"    REL_WHEEL events       : {len(wheel_evs)}  sum={sum(v for _,v in wheel_evs):+d}")
    print(f"    REL_WHEEL_HI_RES events: {len(hires_evs)}  sum={sum(v for _,v in hires_evs):+d}")
    if hires_evs:
        vals = [abs(v) for _, v in hires_evs]
        print(f"    HI_RES max abs val     : {max(vals)}")
    print()

    # Layout discovery: find which byte offset is the wheel
    if wheel_iface_logger is not None and wheel_iface_logger.events:
        print("========== HID LAYOUT DISCOVERY ==========\n")
        # Try every byte offset, count how often it's non-zero in [-8..8].
        # The wheel byte should match evdev REL_WHEEL count closely.
        offset_match = {}
        max_off = max(len(d) for _, d in wheel_iface_logger.events[:200])
        for off in range(min(max_off, 32)):
            non_zero = 0
            value_sum = 0
            extreme = 0
            for _, d in wheel_iface_logger.events:
                if off >= len(d):
                    continue
                v = struct.unpack_from("b", d, off)[0]
                if v != 0:
                    non_zero += 1
                    value_sum += v
                    extreme = max(extreme, abs(v))
            offset_match[off] = (non_zero, value_sum, extreme)
        target_count = len(wheel_evs)
        target_sum = sum(v for _, v in wheel_evs)
        print(f"  evdev target: count={target_count} sum={target_sum:+d}")
        print(f"  Per-offset (signed byte) candidates:")
        print(f"    {'offset':>6} {'non-zero':>9} {'sum':>8} {'max|val|':>9}  match?")
        best_off = None
        best_score = -1
        for off, (cnt, s, ex) in offset_match.items():
            score = 0
            if cnt == target_count:
                score += 10
            elif abs(cnt - target_count) <= 2:
                score += 5
            if s == target_sum:
                score += 10
            elif abs(s - target_sum) <= 3:
                score += 5
            mark = " <-- LIKELY WHEEL" if score >= 15 else ""
            if score > 0:
                print(f"    {off:>6} {cnt:>9} {s:>+8} {ex:>9}{mark}")
            if score > best_score:
                best_score = score
                best_off = off
        print(f"\n  Best guess wheel offset: {best_off}")
        print()

    print("========== RAW REPORT DUMP (first 30) ==========\n")
    if wheel_iface_logger:
        prev_t = None
        for i, (t, data) in enumerate(wheel_iface_logger.events[:30]):
            dt = t - prev_t if prev_t is not None else 0
            prev_t = t
            print(f"  [{i:3d}] t={t:11.1f}ms dt={dt:6.1f}ms len={len(data)} hex={data.hex()}")
        print()

    print("========== REPORTS WITH NON-ZERO WHEEL CANDIDATE ==========\n")
    if wheel_iface_logger and best_off is not None:
        print(f"  Filtering on offset {best_off}, showing first 30 non-zero:")
        n = 0
        prev_t = None
        for t, data in wheel_iface_logger.events:
            if best_off >= len(data):
                continue
            v = struct.unpack_from("b", data, best_off)[0]
            if v == 0:
                continue
            dt = t - prev_t if prev_t is not None else 0
            prev_t = t
            print(f"    t={t:11.1f}ms dt={dt:6.1f}ms wheel={v:+3d} hex={data.hex()}")
            n += 1
            if n >= 30:
                break
        print()

    print("========== EVDEV WHEEL EVENTS (first 30) ==========\n")
    n = 0
    prev_t = None
    for t, name, v in ev_logger.events:
        if name != "WHEEL":
            continue
        dt = t - prev_t if prev_t is not None else 0
        prev_t = t
        print(f"    t={t:11.1f}ms dt={dt:6.1f}ms REL_WHEEL={v:+3d}")
        n += 1
        if n >= 30:
            break


if __name__ == "__main__":
    main()
