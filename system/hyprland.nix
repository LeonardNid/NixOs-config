{ ... }:

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

  # GNOME Keyring: automatisch beim SDDM-Login entsperren
  # Stellt Secret Service bereit, den Vivaldi/Chrome für Passwörter benötigen
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Polkit: benötigt für Berechtigungsdialoge (z.B. WLAN-Passwort, sudo-GUI)
  security.polkit.enable = true;

  services.printing.enable = true;
}
