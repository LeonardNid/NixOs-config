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
  };

  # X11 + Keyboard Layout (wird von SDDM und Xwayland benötigt)
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # PAM-Integration für hyprlock (Sperrbildschirm)
  security.pam.services.hyprlock = {};

  # KWallet via PAM beim SDDM-Login automatisch entsperren
  # (Wallet-Passwort muss = Login-Passwort sein)
  security.pam.services.sddm.kwallet.enable = true;

  # Polkit: benötigt für Berechtigungsdialoge (z.B. WLAN-Passwort, sudo-GUI)
  security.polkit.enable = true;

  # kwalletd6 installieren → D-Bus-Aktivierung + exec-once in Hyprland
  environment.systemPackages = [ pkgs.kdePackages.kwallet ];

  services.printing.enable = true;
}
