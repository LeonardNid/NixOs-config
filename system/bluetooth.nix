{ ... }:

# Bluetooth (beide Hosts) – BlueZ-Stack + Daemon.
# Audio läuft über PipeWire (system/audio.nix), Steuerung via Noctalia / bluetoothctl.
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;          # Adapter beim Booten direkt einschalten
    settings = {
      General = {
        # Akkustand von Kopfhörern/Geräten melden (BLE Battery Service)
        Experimental = true;
      };
    };
  };
}
