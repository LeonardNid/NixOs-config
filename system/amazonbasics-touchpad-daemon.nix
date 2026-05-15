{ pkgs, ... }:

{
  systemd.services.amazonbasics-touchpad-daemon = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "AmazonBasics Touchpad Hotspot + Reading-Layer Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    path = [ pkgs.libnotify pkgs.util-linux ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/amazonbasics-touchpad-daemon.py}";
    };
  };
}
