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

  # GNOME Keyring (libsecret) fuer Browser-Passwortspeicherung
  # Auto-entsperrt sich beim Start wenn das Keyring-Passwort leer ist
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Polkit: benoetigt fuer Berechtigungsdialoge
  security.polkit.enable = true;

  # kwalletd6 + seahorse (Keyring-Manager, zum einmaligen Passwort-Leeren benoetigt)
  environment.systemPackages = [
    pkgs.kdePackages.kwallet
    pkgs.catppuccin-sddm-corners
    pkgs.seahorse
  ];

  services.printing.enable = true;

  # File-Chooser-Dialog für Browser (Drucken/Speichern) und andere GTK-Apps
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.portal.config.niri = {
    default = [ "gtk" ];
    "org.freedesktop.impl.portal.ScreenCast"     = [ "gnome" ];
    "org.freedesktop.impl.portal.Screenshot"     = [ "gnome" ];
    "org.freedesktop.impl.portal.RemoteDesktop"  = [ "gnome" ];
  };
}
