{ pkgs, ... }:

{
  home.packages = with pkgs; [ ydotool ];

  # ydotoold daemon (Wayland-Tastaturemulation für fusuma)
  systemd.user.services.ydotoold = {
    Unit.Description = "ydotool daemon";
    Service = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/user/%U/ydotool_socket";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Fusuma: Touchpad-Gesten für Wayland/KDE Plasma 6
  services.fusuma = {
    enable = true;
    extraPackages = with pkgs; [ ydotool coreutils ];
    settings = {
      threshold = { swipe = 0.05; };
      interval = { swipe = 0; };
      swipe = {
        "3" = {
          up.command   = "YDOTOOL_SOCKET=/run/user/$(id -u)/ydotool_socket ydotool key 125:1 17:1 17:0 125:0";  # Meta+W → Übersicht
          down.command = "YDOTOOL_SOCKET=/run/user/$(id -u)/ydotool_socket ydotool key 125:1 32:1 32:0 125:0"; # Meta+D → Desktop
        };
        "4" = {
          left.command  = "YDOTOOL_SOCKET=/run/user/$(id -u)/ydotool_socket ydotool key 65506:1 65361:1 65361:0 65506:0"; # Ctrl+Left → Desktop wechseln
          right.command = "YDOTOOL_SOCKET=/run/user/$(id -u)/ydotool_socket ydotool key 65506:1 65363:1 65363:0 65506:0"; # Ctrl+Right → Desktop wechseln
        };
      };
    };
  };

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
