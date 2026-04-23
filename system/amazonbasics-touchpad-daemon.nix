{ pkgs, ... }:

{
  systemd.services.amazonbasics-touchpad-daemon = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "AmazonBasics Touchpad Hotspot Daemon (top-left -> Super+O)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/amazonbasics-touchpad-daemon.py}";
    };
  };
}
