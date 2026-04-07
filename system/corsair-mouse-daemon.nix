{ pkgs, ... }:

{
  # Corsair Darkstar Mouse Daemon:
  # Grabbed Maus + Keyboard-Device, normalisiert Scroll-Events,
  # und remappt Extra-Tasten auf Keyboard-Shortcuts.
  systemd.services.corsair-mouse-daemon = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "Corsair Darkstar Mouse Daemon (scroll fix + button remap)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/corsair-mouse-daemon-v2.py}";
    };
  };
}
