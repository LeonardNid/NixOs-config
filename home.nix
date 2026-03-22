{ pkgs, ... }:

{
  home.username = "leonardn";
  home.homeDirectory = "/home/leonardn";
  home.stateVersion = "25.11";

  # User-spezifische Packages (Tools die nur du brauchst)
  home.packages = with pkgs; [
    # Hier kannst du z.B. htop, ripgrep, etc. hinzufügen
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
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#leonardn";
    };
  };

  # Home Manager selbst verwalten lassen
  programs.home-manager.enable = true;
}
