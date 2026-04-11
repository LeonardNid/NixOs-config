#!/usr/bin/env python3
"""
VM Toggle Keyboard Daemon

Creates a persistent virtual keyboard via uinput (named "VMToggleKbd").
QEMU listens to this device as an input-linux source with grab-toggle=scrolllock.

When a trigger is written to the FIFO (/tmp/vm-toggle-kbd.fifo), the daemon
injects a Scroll Lock keypress into the virtual device, causing QEMU to toggle
its evdev grab for all input devices.

Usage in vm-start script:
    echo "toggle" > /tmp/vm-toggle-kbd.fifo
"""

import os
import signal
import sys
import time

from evdev import UInput, ecodes

FIFO_PATH = "/tmp/vm-toggle-kbd.fifo"
DEVICE_NAME = "VMToggleKbd"


def inject_scrolllock(ui):
    ui.write(ecodes.EV_KEY, ecodes.KEY_SCROLLLOCK, 1)
    ui.syn()
    time.sleep(0.05)
    ui.write(ecodes.EV_KEY, ecodes.KEY_SCROLLLOCK, 0)
    ui.syn()


def main():
    caps = {ecodes.EV_KEY: [ecodes.KEY_SCROLLLOCK]}
    ui = UInput(caps, name=DEVICE_NAME)
    print(f"Created virtual keyboard '{DEVICE_NAME}'", file=sys.stderr)

    if os.path.exists(FIFO_PATH):
        os.remove(FIFO_PATH)
    os.mkfifo(FIFO_PATH)
    os.chmod(FIFO_PATH, 0o666)
    print(f"Listening on {FIFO_PATH}", file=sys.stderr)

    def cleanup(signum, frame):
        try:
            ui.close()
        except OSError:
            pass
        try:
            os.remove(FIFO_PATH)
        except OSError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    while True:
        # Blocks until a writer opens the FIFO and writes something
        with open(FIFO_PATH, "r") as f:
            cmd = f.read().strip()
        if cmd == "toggle":
            inject_scrolllock(ui)
            print("Injected Scroll Lock toggle", file=sys.stderr)


if __name__ == "__main__":
    main()
