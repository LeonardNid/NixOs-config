{ ... }:

{
  imports = [
    ./neovim.nix
    ./git.nix
    ./shell.nix
    ./vm.nix
    ./scripts.nix
    ./packages.nix
  ];

  home.username = "leonardn";
  home.homeDirectory = "/home/leonardn";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
