{ pkgs, ... }:

{
  # Corsair Darkstar Scroll-Fix:
  # Grabbed die Maus, blockiert Hi-Res Scroll Events, teilt Scroll-Werte durch 10,
  # und entprellt kurze Richtungsumkehrungen (Encoder-Bounce).
  systemd.services.corsair-scroll-fix = let
    python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  in {
    description = "Corsair Darkstar Scroll Wheel Fix";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${python}/bin/python3 ${../scripts/corsair-scroll-fix.py}";
    };
  };
}
