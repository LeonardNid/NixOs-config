{ pkgs, ... }:

{
  programs.firefox.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  environment.systemPackages = with pkgs; [
    borgbackup
    wget
    nodejs
    vesktop
    (vivaldi.override { commandLineArgs = "--password-store=kwallet6 --ozone-platform=wayland --enable-features=WaylandWindowDecorations"; })
    tailscale
    easyeffects
    obsidian
    zapzap
    mpv
    vlc
    imv
    file-roller
    drawing
    gimp
    libreoffice-qt6-fresh
    gemini-cli
    # qutebrowser
    mission-center
    signal-desktop
    # rustdesk-flutter
    zoxide
    neovim
  ];
}
