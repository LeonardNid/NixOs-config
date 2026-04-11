import evdev
import sys

print("Testing if we can read ScrollLock without grab...")
devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
voyagers = [d for d in devices if "Voyager" in d.name]
if not voyagers:
    print("No voyagers found")
    sys.exit(1)

print(f"Found {len(voyagers)} voyagers.")
