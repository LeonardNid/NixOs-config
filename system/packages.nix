{ pkgs, ... }:

{
  programs.firefox.enable = true;

  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
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
    zoxide
    drawing
    # gimp
    libreoffice-qt6-fresh
    gemini-cli
    qutebrowser
    mission-center
    signal-desktop
  ];
}
