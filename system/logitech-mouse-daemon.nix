{ pkgs, ... }:

{
  systemd.services.logitech-mouse-daemon = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "Logitech G403 HERO Mouse Daemon (evdev passthrough)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/logitech-mouse-daemon.py}";
    };
  };
}
