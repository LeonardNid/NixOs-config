{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # wl-clipboard
    zoxide
    neovim
    keymapp
    libnotify
    yazi
    helix
    broot
    ripgrep
    btop
    fzf
    fd
    bat
    wtype
    eza
    git-lfs
    jq
    zathura
  ];


}
