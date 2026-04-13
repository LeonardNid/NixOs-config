{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wl-clipboard
    keymapp
    libnotify
  ];
}
