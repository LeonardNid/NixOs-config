{ pkgs, ... }:

{
  # Steam braucht System-Integration (32-bit-Libs, Grafiktreiber, Firewall) → system
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  # GameMode: System-Daemon (CPU-Governor / Nice-Level via Polkit) → system
  programs.gamemode.enable = true;
  # Gamescope: braucht setcap-Wrapper (CAP_SYS_NICE) → system
  programs.gamescope.enable = true;

  # Nur Pakete, die wirklich Root brauchen oder an einen System-Dienst gekoppelt sind.
  # Alles Übrige (GUI-Apps, User-CLI-Tools) liegt in home/packages.nix.
  environment.systemPackages = with pkgs; [
    tailscale     # Root-CLI, gehört zum services.tailscale-Dienst (system/users.nix)
    borgbackup    # System-Backups laufen als root
  ];
}
