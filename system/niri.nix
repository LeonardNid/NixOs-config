{ pkgs, ... }:

{
  # niri-flake NixOS-Modul (programs.niri.enable, XDG Portal, Polkit-Agent) wird
  # automatisch via flake.nix eingebunden
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  # Login manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-sddm-corners";
    extraPackages = [ pkgs.kdePackages.qt5compat ];
  };

  # X11 + Keyboard Layout (SDDM + Xwayland)
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # PAM-Integration fuer swaylock (Sperrbildschirm)
  security.pam.services.swaylock = {};

  # SDDM anweisen, KWallet beim Login zu entsperren
  security.pam.services.sddm.kwallet.enable = true;

  # Polkit: benoetigt fuer Berechtigungsdialoge
  security.polkit.enable = true;

  # kwalletd6 bereitstellen
  environment.systemPackages = [
    pkgs.kdePackages.kwallet
    pkgs.catppuccin-sddm-corners
  ];

  services.printing.enable = true;

  # File-Chooser-Dialog für Browser (Drucken/Speichern) und andere GTK-Apps
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.niri.default = [ "gnome" "gtk" ];
}
