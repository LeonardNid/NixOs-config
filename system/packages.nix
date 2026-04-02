{ pkgs, ... }:

{
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    nodejs
    vesktop
    vivaldi
    tailscale
    easyeffects
    obsidian
    nextcloud-client
    zapzap
    vscode
    mpv
    vlc
    zoxide
  ];
}
