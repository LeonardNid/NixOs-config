{ ... }:

{
  imports = [
    ./neovim.nix
    ./git.nix
    ./shell.nix
    ./scripts.nix
    ./packages.nix
    ./vscode.nix
    ./zed.nix
    ./xdg.nix
    ./navi.nix
    ./nextcloud.nix
  ];

  home.username = "leonardn";
  home.homeDirectory = "/home/leonardn";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
