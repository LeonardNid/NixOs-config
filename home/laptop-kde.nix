{ pkgs, lib, ... }:

let
  qdbus = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut";
  # flock verhindert Mehrfachauslösung: Lock wird für 0.8s gehalten
  once = cmd: "flock -n /tmp/fusuma-ws.lock sh -c \"${cmd} && sleep 0.8\"";
in
{
  # KWin-Latenz und Animationsgeschwindigkeit optimieren
  home.activation.kwinLatencyFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kdeglobals --group KDE --key AnimationDurationFactor 0.5
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Compositing --key LatencyPolicy Low
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group TabBox --key DelayTime 0
  '';

  # Lockscreen: nach 5 Minuten Inaktivität + beim Aufwachen aus Suspend
  home.activation.lockscreen = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kscreenlockerrc --group Daemon --key Autolock true
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kscreenlockerrc --group Daemon --key Timeout 5
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kscreenlockerrc --group Daemon --key LockOnResume true
  '';

  # Fusuma: Touchpad-Gesten für Wayland/KDE Plasma 6
  services.fusuma = {
    enable = true;
    extraPackages = with pkgs; [ coreutils qt6.qttools util-linux ];
    settings = {
      threshold = { swipe = 0.05; };
      interval = { swipe = 1; };
      swipe = {
        "3" = {
          up.command    = "${qdbus} 'Toggle Overview'";
          down.command  = "${qdbus} 'ExposeAll'";
          left.command  = once "${qdbus} 'Switch to Next Desktop'";
          right.command = once "${qdbus} 'Switch to Previous Desktop'";
        };
        "4" = {
          left.command  = once "${qdbus} 'Switch to Next Desktop'";
          right.command = once "${qdbus} 'Switch to Previous Desktop'";
        };
      };
    };
  };
}
