{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wl-clipboard
    keymapp
    libnotify
  ];

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
