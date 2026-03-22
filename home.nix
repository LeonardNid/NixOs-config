{ pkgs, ... }:

{
  home.username = "leonardn";
  home.homeDirectory = "/home/leonardn";
  home.stateVersion = "25.11";

  # User-spezifische Packages (Tools die nur du brauchst)
  home.packages = with pkgs; [
    (writeShellScriptBin "rebuild" ''
      cd /etc/nixos
      git add .
      if ! git diff --cached --quiet; then
        git commit -m "''${1:-nixos: $(date '+%Y-%m-%d %H:%M')}"
      fi
      sudo nixos-rebuild switch --flake /etc/nixos#leonardn
      git push
    '')
  ];

  # Git Konfiguration
  programs.git = {
    enable = true;
    userName = "Leonard Niedens";
    userEmail = "niedens03@gmail.com";
    extraConfig.init.defaultBranch = "main";
  };

  # Zsh Konfiguration
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
    };
  };

  # Home Manager selbst verwalten lassen
  programs.home-manager.enable = true;
}
