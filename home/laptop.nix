{ pkgs, ... }:

{
  # Fusuma: Touchpad-Gesten für Wayland/KDE Plasma 6
  services.fusuma = {
    enable = true;
    extraPackages = with pkgs; [ coreutils qt6.qttools ];
    settings = {
      threshold = { swipe = 0.05; };
      interval = { swipe = 0; };
      swipe = {
        "3" = {
          up.command   = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Overview'";
          down.command = "qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'";
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
