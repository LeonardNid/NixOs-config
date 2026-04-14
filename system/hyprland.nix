{ ... }:

{
  # Hyprland Wayland compositor
  programs.hyprland.enable = true;

  # Login manager (unterstützt KDE- und Hyprland-Sessions)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # PAM-Integration für hyprlock (Sperrbildschirm)
  security.pam.services.hyprlock = {};

  # Polkit: benötigt für Berechtigungsdialoge (z.B. WLAN-Passwort, sudo-GUI)
  security.polkit.enable = true;

  services.printing.enable = true;
}
