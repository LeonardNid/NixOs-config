{ pkgs, ... }:

{
  home.packages = [ pkgs.navi ];

  # Cheat-Dateien aus der nixos-config verlinken
  home.file.".local/share/navi/cheats/git.cheat".source = ./navi/git.cheat;
  home.file.".local/share/navi/cheats/tailscale.cheat".source = ./navi/tailscale.cheat;

  # Zsh-Widget: Ctrl+G öffnet navi mit fzf
  programs.zsh.initContent = ''
    eval "$(navi widget zsh)"
  '';
}
