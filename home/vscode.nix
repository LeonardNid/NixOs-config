{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override { commandLineArgs = "--password-store=kwallet6"; };
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        github.copilot
        github.copilot-chat
        vscodevim.vim
      ];
      userSettings = {
        "editor.lineNumbers" = "relative";
        "explorer.confirmDragAndDrop" = false;
        "github.copilot.enable" = {
          "*" = false;
          "plaintext" = false;
          "markdown" = false;
          "scminput" = false;
        };
        "vim.useSystemClipboard" = true;
        # Strg+C/V/X von VS Code (Standard-Copy/Paste/Cut) behandeln lassen,
        # statt von Vim. Maus-Markieren + Strg+C/V funktioniert damit wie gewohnt.
        "vim.handleKeys" = {
          "<C-f>" = false;
          "<C-c>" = false;
          "<C-v>" = false;
          "<C-x>" = false;
        };
      };
    };
  };
}
