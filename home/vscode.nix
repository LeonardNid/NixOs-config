{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true; # erlaubt manuelle Extensions zusätzlich zu Nix-verwalteten
    extensions = with pkgs.vscode-extensions; [
      github.copilot
      github.copilot-chat
    ];
  };
}
