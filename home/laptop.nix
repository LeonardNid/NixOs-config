{ pkgs, lib, ... }:

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

  # Fusuma: Touchpad-Gesten für Wayland/KDE Plasma 6
  services.fusuma = {
    enable = true;
    extraPackages = with pkgs; [ coreutils qt6.qttools ];
    settings = {
      threshold = { swipe = 0.05; };
      interval = { swipe = 1; };
      swipe = {
        "3" = {
          up.command    = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Overview'";
          down.command  = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'";
          left.command  = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Switch to Next Desktop'";
          right.command = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Switch to Previous Desktop'";
        };
        "4" = {
          left.command  = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Switch to Next Desktop'";
          right.command = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Switch to Previous Desktop'";
        };
      };
    };
  };

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
