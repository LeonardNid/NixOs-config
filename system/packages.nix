{ pkgs, ... }:

{
  programs.firefox.enable = true;

  programs.steam.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    nodejs
    vesktop
    (vivaldi.override { commandLineArgs = "--password-store=kwallet6"; })
    tailscale
    easyeffects
    obsidian
    zapzap
    mpv
    vlc
    zoxide
    drawing
    gimp2-with-plugins
    libreoffice-qt6-fresh
    gemini-cli
    qutebrowser
    mission-center
  ];
}
