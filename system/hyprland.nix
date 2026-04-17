{ pkgs, ... }:

{
  # Hyprland Wayland compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;   # X11-App-Unterstützung in Hyprland
  };

  # Login manager (unterstützt KDE- und Hyprland-Sessions)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-sddm-corners";
    extraPackages = [ pkgs.kdePackages.qt5compat ];
    settings.General = {
      CursorTheme = "breeze_cursors";
      CursorSize = 24;
    };
  };

  # X11 + Keyboard Layout (wird von SDDM und Xwayland benötigt)
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # PAM-Integration für hyprlock (Sperrbildschirm)
  security.pam.services.hyprlock = {};

  # SDDM anweisen, KWallet beim Login zu entsperren
  security.pam.services.sddm.kwallet.enable = true;

  # Polkit: benötigt für Berechtigungsdialoge (z.B. WLAN-Passwort, sudo-GUI)
  security.polkit.enable = true;

  # kwalletd6 bereitstellen (PAM-Unlock läuft über system/laptop.nix → login-Service)
  environment.systemPackages = [
    pkgs.kdePackages.kwallet
    pkgs.kdePackages.breeze
    pkgs.catppuccin-sddm-corners
  ];

  services.printing.enable = true;

  # SDDM Wayland: Software-Cursor erzwingen (Hardware-Cursor-Plane funktioniert nicht)
  systemd.services.sddm.environment.WLR_NO_HARDWARE_CURSORS = "1";
}
