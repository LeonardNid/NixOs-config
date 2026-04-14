{ ... }:

{
  # Nextcloud-Sync (desktop-agnostisch, läuft in KDE und Hyprland)
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
