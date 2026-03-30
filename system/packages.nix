{ pkgs, ... }:

{
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    nodejs
    discord
    vivaldi
    tailscale
    easyeffects
    obsidian
    nextcloud-client
    zapzap
    vscode
  ];
}
