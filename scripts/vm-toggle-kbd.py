#!/usr/bin/env python3
"""
VM Toggle Keyboard Forwarding Daemon

Proxy for ZSA Voyager keyboard. Allows toggling focus between Linux host and VM.
When in VM mode, it grabs the physical keyboard and forwards keystrokes to VirtualVoyager.
When ScrollLock is pressed, it ungrabs the keyboard (so Linux can see it), and injects
a ScrollLock into VMToggleKbd to release QEMU's mouse grab.
A command written to /tmp/vm-toggle-kbd.fifo toggles it back to VM mode.
"""

import os
import signal
import sys
import time
import select

import evdev
from evdev import UInput, ecodes

FIFO_PATH = "/tmp/vm-toggle-kbd.fifo"
TOGGLE_DEVICE_NAME = "VMToggleKbd"
VIRTUAL_DEVICE_NAME = "VirtualVoyager"

VENDOR_ZSA = 0x3297
PRODUCT_VOYAGER = 0x1977

def find_voyager_devices():
    devices = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            if dev.info.vendor == VENDOR_ZSA and dev.info.product == PRODUCT_VOYAGER:
                devices.append(dev)
            else:
                dev.close()
        except OSError:
            pass
    return devices

def build_combined_caps(devices):
    caps = {}
    for dev in devices:
        for event_type, event_codes in dev.capabilities().items():
            if event_type == ecodes.EV_SYN:
                continue
            if event_type not in caps:
                caps[event_type] = set()
            for code in event_codes:
                if isinstance(code, tuple):
                    caps[event_type].add(code[0])
                else:
                    caps[event_type].add(code)
                    
    # Convert sets to lists
    return {k: list(v) for k, v in caps.items()}

def inject_scrolllock(ui):
    ui.write(ecodes.EV_KEY, ecodes.KEY_SCROLLLOCK, 1)
    ui.syn()
    time.sleep(0.05)
    ui.write(ecodes.EV_KEY, ecodes.KEY_SCROLLLOCK, 0)
    ui.syn()

def set_grab(devices, grab):
    for dev in devices:
        try:
            if grab:
                dev.grab()
            else:
                dev.ungrab()
        except OSError as e:
            if e.errno != 22:  # Ignore Invalid argument (already grabbed/ungrabbed)
                print(f"Failed to {'grab' if grab else 'ungrab'} {dev.name}: {e}", file=sys.stderr)

def main():
    devices = find_voyager_devices()
    if not devices:
        print("No ZSA Voyager devices found. Waiting for udev...", file=sys.stderr)
        # Exit so systemd restarts us
        sys.exit(1)

    print(f"Found {len(devices)} ZSA Voyager devices:", file=sys.stderr)
    for dev in devices:
        print(f" - {dev.name} at {dev.path}", file=sys.stderr)

    # 1. Create Virtual Voyager
    virtual_caps = build_combined_caps(devices)
    if ecodes.EV_KEY not in virtual_caps:
        virtual_caps[ecodes.EV_KEY] = []
    if ecodes.KEY_SCROLLLOCK not in virtual_caps[ecodes.EV_KEY]:
        virtual_caps[ecodes.EV_KEY].append(ecodes.KEY_SCROLLLOCK)
        
    virtual_ui = UInput(virtual_caps, name=VIRTUAL_DEVICE_NAME, vendor=VENDOR_ZSA, product=PRODUCT_VOYAGER)
    print(f"Created virtual keyboard '{VIRTUAL_DEVICE_NAME}'", file=sys.stderr)

    # 2. Create VM Toggle Keyboard
    toggle_caps = {ecodes.EV_KEY: [ecodes.KEY_SCROLLLOCK]}
    toggle_ui = UInput(toggle_caps, name=TOGGLE_DEVICE_NAME)
    print(f"Created virtual keyboard '{TOGGLE_DEVICE_NAME}'", file=sys.stderr)

    # 3. Setup FIFO
    if os.path.exists(FIFO_PATH):
        try:
            os.remove(FIFO_PATH)
        except OSError:
            pass
    os.mkfifo(FIFO_PATH)
    os.chmod(FIFO_PATH, 0o666)
    
    # Open FIFO for non-blocking reading using O_RDWR so it never emits EOF
    fifo_fd = os.open(FIFO_PATH, os.O_RDWR | os.O_NONBLOCK)
    fifo_file = os.fdopen(fifo_fd, "r")
    print(f"Listening on {FIFO_PATH}", file=sys.stderr)

    # Initial state
    is_vm_mode = False
    set_grab(devices, is_vm_mode)

    # Held combo keys tracking (to release on untoggle)
    held_keys = set()
    
    def cleanup(signum, frame):
        try:
            virtual_ui.close()
            toggle_ui.close()
        except OSError:
            pass
        set_grab(devices, False)
        try:
            os.remove(FIFO_PATH)
        except OSError:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    while True:
        try:
            r, _, _ = select.select(devices + [fifo_file], [], [])
        except OSError:
            break
        
        for readable in r:
            if readable is fifo_file:
                cmd = fifo_file.readline().strip()
                if cmd == "toggle":
                    # Blind toggle between VM and Linux mode
                    is_vm_mode = not is_vm_mode
                    print(f"Toggled mode via FIFO: VM_MODE={is_vm_mode}", file=sys.stderr)
                    set_grab(devices, is_vm_mode)
                    
                    if is_vm_mode:
                        # Clear held keys just in case
                        held_keys.clear()
                    else:
                        # Release any keys still held in the VM
                        for key in held_keys:
                            try:
                                virtual_ui.write(ecodes.EV_KEY, key, 0)
                            except OSError:
                                pass
                        virtual_ui.syn()
                        held_keys.clear()

                    # Always inject a ScrollLock into VMToggleKbd to make QEMU toggle its mouse grab
                    inject_scrolllock(toggle_ui)
            else:
                # Event from physical keyboard
                try:
                    for event in readable.read():
                        if is_vm_mode:
                            if event.type == ecodes.EV_KEY and event.code == ecodes.KEY_SCROLLLOCK and event.value == 1:
                                # Switch to Linux mode
                                is_vm_mode = False
                                print("ScrollLock pressed on Voyager. Switching to Linux mode.", file=sys.stderr)
                                set_grab(devices, is_vm_mode)
                                
                                # Release any keys still held in the VM
                                for key in held_keys:
                                    try:
                                        virtual_ui.write(ecodes.EV_KEY, key, 0)
                                    except OSError:
                                        pass
                                virtual_ui.syn()
                                held_keys.clear()

                                inject_scrolllock(toggle_ui)
                            else:
                                # Forward to VirtualVoyager
                                virtual_ui.write_event(event)
                                if event.type == ecodes.EV_SYN:
                                    virtual_ui.syn()
                                elif event.type == ecodes.EV_KEY:
                                    if event.value == 1:
                                        held_keys.add(event.code)
                                    elif event.value == 0:
                                        held_keys.discard(event.code)
                except OSError:
                    print(f"Device error on {readable.name}. Exiting to restart.", file=sys.stderr)
                    cleanup(0, None)

if __name__ == "__main__":
    main()
