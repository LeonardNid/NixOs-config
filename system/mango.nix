{ pkgs, ... }:

{
  # Mango Wayland compositor
  programs.mango.enable = true;

  # Login manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # X11 + Keyboard Layout (wird von SDDM und Xwayland benötigt)
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # PAM-Integration für swaylock (Sperrbildschirm)
  security.pam.services.swaylock = {};

  # SDDM anweisen, KWallet beim Login zu entsperren
  security.pam.services.sddm.kwallet.enable = true;

  # Polkit: benötigt für Berechtigungsdialoge
  security.polkit.enable = true;

  # kwalletd6 bereitstellen
  environment.systemPackages = [ pkgs.kdePackages.kwallet ];

  services.printing.enable = true;
}
