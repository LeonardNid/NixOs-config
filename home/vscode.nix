{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override { commandLineArgs = "--password-store=kwallet6"; };
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        github.copilot
        github.copilot-chat
      ];
    };
  };
}
